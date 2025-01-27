import os
import asyncio
import mimetypes
from pathlib import Path
from typing import List, Optional

class FileCombiner:
    """
    A utility class to combine text-based project files into one text file
    and produce a structured summary of all scanned files (included or skipped).

    Usage:
        combiner = FileCombiner(
            output_file="combined_output.txt",
            max_size=1024*1024,  # 1MB per file
            ignore_files=["script.py", "package-lock.json"],
            ignore_dirs=[".git", "node_modules", "dist", "build", ".next"],
            verbose=True
        )
        asyncio.run(combiner.combine_files())
    """

    def __init__(self,
                 output_file: str = "combined_output.txt",
                 max_size: int = 1_024 * 1_024,  # 1 MB
                 ignore_files: Optional[List[str]] = None,
                 ignore_dirs: Optional[List[str]] = None,
                 verbose: bool = False) -> None:
        """
        Initializes the FileCombiner with parameters for output file name,
        max file size, and lists of files/directories to ignore.
        """
        self.output_file = output_file
        self.max_size = max_size
        self.verbose = verbose

        # Default ignored files & directories (extend as needed)
        self.ignore_files = set(ignore_files or [])
        self.ignore_files.add(self.output_file)  # Always ignore the output file
        # Common directories to ignore
        self.ignore_dirs = set(ignore_dirs or [
            ".git", "node_modules", "dist", "build", ".next", ".cache", ".venv",
            "build_backup", "build_new", "dataconnect-generated", "fav", "public"
        ])

    def log(self, message: str) -> None:
        """Helper method for optional verbose logging."""
        if self.verbose:
            print(message)

    def is_text_file(self, file_path: Path) -> bool:
        """
        Check if a file is likely text-based.
        1. Check common binary extensions.
        2. Fallback to mimetype detection.
        3. If uncertain, do a quick binary sniff for null bytes or large non-ASCII portion.
        """
        # Common known binary extensions to skip
        binary_extensions = {
            '.png', '.jpg', '.jpeg', '.gif', '.ico', '.svg',
            '.woff', '.woff2', '.ttf', '.eot', '.otf',
            '.mp3', '.mp4', '.webm', '.ogg', '.pdf',
            '.zip', '.gz', '.rar', '.7z'
        }
        if file_path.suffix.lower() in binary_extensions:
            return False

        # Fallback: use mimetypes to detect if it's text
        mime_type, _ = mimetypes.guess_type(file_path)
        if mime_type and not mime_type.startswith("text"):
            # For example, .js might come back as text/javascript (which is fine).
            # But if it’s application/octet-stream, it might be binary.
            if mime_type == "application/octet-stream":
                # Double-check by sniffing content
                if not self._binary_sniff(file_path):
                    return True  # Possibly text
                else:
                    return False
            # If it's something else known not to be text, skip
            if not mime_type.startswith("text"):
                return False

        # As a last step, sniff file content for binary indicators
        return not self._binary_sniff(file_path)

    def _binary_sniff(self, file_path: Path, chunk_size: int = 1024) -> bool:
        """
        Returns True if the file appears to be binary by scanning for:
        1) Null bytes
        2) High ratio of non-ASCII characters
        """
        try:
            with open(file_path, 'rb') as f:
                chunk = f.read(chunk_size)
                if b'\x00' in chunk:
                    return True  # probably binary

                # Check ratio of non-ASCII
                non_ascii_count = sum(byte > 127 for byte in chunk)
                if len(chunk) > 0 and (non_ascii_count / len(chunk) > 0.3):
                    return True
            return False
        except Exception:
            # If we can't read it, assume it's binary or unreadable
            return True

    def check_file_size(self, file_path: Path) -> bool:
        """Check if file size is within the allowed max_size limit."""
        return file_path.stat().st_size <= self.max_size

    def should_ignore(self, file_path: Path) -> bool:
        """
        Determine if a file should be ignored based on:
        1) Its filename being in `ignore_files`.
        2) Any parent directory being in `ignore_dirs`.
        """
        if file_path.name in self.ignore_files:
            return True

        # Check if any parent directory is in ignore_dirs
        for part in file_path.parts:
            if part in self.ignore_dirs:
                return True

        return False

    async def process_file(self, file_path: Path) -> dict:
        """
        Asynchronously process a single file and return a dictionary with:
            - path: Path of the file
            - included: bool (True if file will be included)
            - reason: str (reason for skipping or "Included" if included)
            - content: str (the file content if included, else "")
            - size: int (size in bytes)

        This metadata dictionary helps in building a summary.
        """
        metadata = {
            'path': str(file_path),
            'size': file_path.stat().st_size,
            'included': False,
            'reason': '',
            'content': ''
        }

        # Check if we should ignore
        if self.should_ignore(file_path):
            metadata['reason'] = "Ignored (matched ignore list)"
            return metadata

        # Check if it's text
        if not self.is_text_file(file_path):
            metadata['reason'] = "Skipped (binary or non-text)"
            return metadata

        # Check size
        if not self.check_file_size(file_path):
            metadata['reason'] = "Skipped (file too large)"
            return metadata

        # If passed all checks, read content
        try:
            with file_path.open('r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            metadata['included'] = True
            metadata['reason'] = "Included"
            metadata['content'] = f"// File: {file_path}\n{'-'*40}\n{content}\n\n"
            self.log(f"Including: {file_path}")
        except Exception as e:
            metadata['reason'] = f"Error reading file: {e}"

        return metadata

    async def combine_files(self) -> str:
        """
        Recursively scans the current directory (and subdirectories),
        combines text content of each file, and saves to `self.output_file`.

        Also generates a structured Markdown summary (table of contents).
        Returns the path to the output file as a string.
        """
        base_path = Path(".")
        all_files = [p for p in base_path.rglob("*") if p.is_file()]

        # Process files in parallel
        tasks = [self.process_file(file_path) for file_path in all_files]
        results = await asyncio.gather(*tasks)

        # Separate included vs skipped
        included_files = [res for res in results if res['included']]
        skipped_files = [res for res in results if not res['included']]

        # Build a Markdown summary
        summary_lines = []
        summary_lines.append("# Project Files Summary\n\n")
        
        # Summary stats
        total_count = len(results)
        included_count = len(included_files)
        skipped_count = len(skipped_files)
        summary_lines.append(f"- **Total files scanned**: {total_count}\n")
        summary_lines.append(f"- **Files included**: {included_count}\n")
        summary_lines.append(f"- **Files skipped**: {skipped_count}\n\n")

        # Table of included files
        summary_lines.append("## Included Files\n")
        if included_count:
            summary_lines.append("| File | Size (bytes) | \n|------|--------------|\n")
            for res in included_files:
                summary_lines.append(f"| `{res['path']}` | {res['size']} |\n")
        else:
            summary_lines.append("_No files included._\n")
        summary_lines.append("\n")

        # Table of skipped files
        summary_lines.append("## Skipped Files\n")
        if skipped_count:
            summary_lines.append("| File | Size (bytes) | Reason |\n|------|--------------|--------|\n")
            for res in skipped_files:
                summary_lines.append(
                    f"| `{res['path']}` | {res['size']} | {res['reason']} |\n"
                )
        else:
            summary_lines.append("_No files skipped._\n")
        summary_lines.append("\n")

        # Now collect actual file contents
        combined_content = []
        # Write the summary at the top
        combined_content.extend(summary_lines)

        # Then write each included file's content
        combined_content.append("---\n## Combined File Contents\n\n")
        for res in included_files:
            combined_content.append(res['content'])

        # Write combined content to the output file
        with open(self.output_file, 'w', encoding='utf-8') as out_f:
            out_f.writelines(combined_content)

        print(f"Successfully combined {len(included_files)} files into {self.output_file}")
        return self.output_file


# Usage Example
async def main():
    combiner = FileCombiner(
        output_file="combined_output.txt",
        max_size=1024 * 1024,  # 1MB
        ignore_files=["script.py", ".env"],  # add more if needed
        ignore_dirs=[".git", "node_modules", "dist", "build", ".next", ".cache",
                     "build_backup", "build_new", "dataconnect-generated", "fav", "public"],
        verbose=True  # set to True to see which files are processed or skipped
    )
    output_file = await combiner.combine_files()
    print(f"Combined output written to: {output_file}")


if __name__ == "__main__":
    asyncio.run(main())
