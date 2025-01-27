import os
import asyncio
import mimetypes
from pathlib import Path
from typing import List, Optional

class FileCombiner:
    """
    A utility class to combine text-based project files into one text file 
    (e.g., for providing context to LLMs or archiving).

    Usage:
        combiner = FileCombiner(
            output_file="combined_output.txt",
            max_size=1024*1024,  # 1MB per file
            ignore_files=["script.py", "package-lock.json"],
            ignore_dirs=[".git", "node_modules", "dist", "build", ".next"]
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
        # Common directories to ignore: .git, node_modules, dist, build, .next, etc.
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
            # For example, .js might come back as text/javascript, which is fine.
            # But if it’s application/octet-stream, it might be binary.
            if mime_type == "application/octet-stream":
                # Double-check by sniffing content
                if not self._binary_sniff(file_path):
                    return True
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

    async def process_file(self, file_path: Path) -> Optional[str]:
        """
        Asynchronously process a single file and return its content with a header.
        Returns None if the file is ignored or is not text-based or is too large.
        """
        if self.should_ignore(file_path):
            self.log(f"Ignoring (matched ignore list): {file_path}")
            return None

        if not self.is_text_file(file_path):
            self.log(f"Skipping (binary or non-text): {file_path}")
            return None

        if not self.check_file_size(file_path):
            self.log(f"Skipping (file too large): {file_path}")
            return None

        try:
            with file_path.open('r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                self.log(f"Including: {file_path}")
                return f"// File: {file_path}\n{'-'*40}\n{content}\n\n"
        except Exception as e:
            self.log(f"Error reading {file_path}: {e}")
            return None

    async def combine_files(self) -> str:
        """
        Recursively scans the current directory (and subdirectories),
        combines text content of each file, and saves to `self.output_file`.
        
        Returns the path to the output file as a string.
        """
        base_path = Path(".")
        # Collect all file paths in a list before processing
        all_files = [p for p in base_path.rglob("*") if p.is_file()]

        # Process the files asynchronously in one gather call
        tasks = [self.process_file(file_path) for file_path in all_files]
        results = await asyncio.gather(*tasks)

        # Filter out None results
        combined_content = [res for res in results if res]

        # Write combined content to output file
        with open(self.output_file, 'w', encoding='utf-8') as out_f:
            out_f.writelines(combined_content)

        print(f"Successfully combined {len(combined_content)} files into {self.output_file}")
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