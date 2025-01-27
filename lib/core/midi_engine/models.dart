/// Settings for MIDI extraction
class MidiExtractionSettings {
  /// Onset detection threshold (0.0 to 1.0)
  final double onsetThreshold;

  /// Frame-level threshold (0.0 to 1.0)
  final double frameThreshold;

  /// Minimum note length in milliseconds
  final double minNoteLength;

  /// Minimum frequency in Hz
  final double minimumFrequency;

  /// Maximum frequency in Hz
  final double maximumFrequency;

  /// Whether to use multiple pitch bends
  final bool multiplePitchBends;

  /// Whether to use the Melodia trick for better melody extraction
  final bool melodiaTrick;

  const MidiExtractionSettings({
    this.onsetThreshold = 0.5,
    this.frameThreshold = 0.3,
    this.minNoteLength = 50.0,
    this.minimumFrequency = 20.0,
    this.maximumFrequency = 2000.0,
    this.multiplePitchBends = false,
    this.melodiaTrick = true,
  });
}

/// Settings for MIDI playback
class MidiPlaybackSettings {
  /// Playback tempo in BPM
  final double tempo;

  /// Whether to loop playback
  final bool loopEnabled;

  /// Playback volume (0.0 to 1.0)
  final double volume;

  const MidiPlaybackSettings({
    this.tempo = 120.0,
    this.loopEnabled = false,
    this.volume = 1.0,
  });
}

/// Represents a MIDI project containing multiple tracks
class MidiProject {
  /// Unique identifier for the project
  final String id;

  /// List of MIDI tracks in the project
  final List<MidiTrack> tracks;

  /// Project metadata
  final MidiMetadata metadata;

  const MidiProject({
    required this.id,
    required this.tracks,
    required this.metadata,
  });

  /// Create a MidiProject from JSON
  factory MidiProject.fromJson(Map<String, dynamic> json) {
    return MidiProject(
      id: json['id'] as String,
      tracks: (json['tracks'] as List)
          .map((track) => MidiTrack.fromJson(track as Map<String, dynamic>))
          .toList(),
      metadata: MidiMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );
  }

  /// Convert MidiProject to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tracks': tracks.map((track) => track.toJson()).toList(),
      'metadata': metadata.toJson(),
    };
  }
}

/// Represents a single MIDI track
class MidiTrack {
  /// Unique identifier for the track
  final String id;

  /// Track name
  final String name;

  /// List of MIDI notes in the track
  final List<MidiNote> notes;

  /// MIDI channel (0-15)
  final int channel;

  /// Whether the track is muted
  final bool muted;

  /// Whether the track is soloed
  final bool soloed;

  const MidiTrack({
    required this.id,
    required this.name,
    required this.notes,
    this.channel = 0,
    this.muted = false,
    this.soloed = false,
  });

  /// Create a MidiTrack from JSON
  factory MidiTrack.fromJson(Map<String, dynamic> json) {
    return MidiTrack(
      id: json['id'] as String,
      name: json['name'] as String,
      notes: (json['notes'] as List)
          .map((note) => MidiNote.fromJson(note as Map<String, dynamic>))
          .toList(),
      channel: json['channel'] as int? ?? 0,
      muted: json['muted'] as bool? ?? false,
      soloed: json['soloed'] as bool? ?? false,
    );
  }

  /// Convert MidiTrack to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'notes': notes.map((note) => note.toJson()).toList(),
      'channel': channel,
      'muted': muted,
      'soloed': soloed,
    };
  }
}

/// Represents a single MIDI note
class MidiNote {
  /// MIDI note number (0-127)
  final int pitch;

  /// Note velocity (0-127)
  final int velocity;

  /// Start time in seconds
  final double startTime;

  /// Duration in seconds
  final double duration;

  const MidiNote({
    required this.pitch,
    required this.velocity,
    required this.startTime,
    required this.duration,
  });

  /// Create a MidiNote from JSON
  factory MidiNote.fromJson(Map<String, dynamic> json) {
    return MidiNote(
      pitch: json['pitch'] as int,
      velocity: json['velocity'] as int,
      startTime: (json['startTime'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
    );
  }

  /// Convert MidiNote to JSON
  Map<String, dynamic> toJson() {
    return {
      'pitch': pitch,
      'velocity': velocity,
      'startTime': startTime,
      'duration': duration,
    };
  }
}

/// Metadata for a MIDI project
class MidiMetadata {
  /// Project title
  final String title;

  /// Artist name
  final String? artist;

  /// Project tempo in BPM
  final int tempo;

  /// Time signature numerator
  final int? timeSignatureNumerator;

  /// Time signature denominator
  final int? timeSignatureDenominator;

  const MidiMetadata({
    required this.title,
    this.artist,
    this.tempo = 120,
    this.timeSignatureNumerator,
    this.timeSignatureDenominator,
  });

  /// Create MidiMetadata from JSON
  factory MidiMetadata.fromJson(Map<String, dynamic> json) {
    return MidiMetadata(
      title: json['title'] as String,
      artist: json['artist'] as String?,
      tempo: json['tempo'] as int? ?? 120,
      timeSignatureNumerator: json['timeSignatureNumerator'] as int?,
      timeSignatureDenominator: json['timeSignatureDenominator'] as int?,
    );
  }

  /// Convert MidiMetadata to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'tempo': tempo,
      'timeSignatureNumerator': timeSignatureNumerator,
      'timeSignatureDenominator': timeSignatureDenominator,
    };
  }
}
