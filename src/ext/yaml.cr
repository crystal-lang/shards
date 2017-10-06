require "yaml"

module YAML
  class PullParser
    # Iterates a sequence, yielding on each new entry until the sequence is
    # terminated.
    def each_in_sequence : Nil
      read_sequence_start
      until kind == YAML::EventKind::SEQUENCE_END
        yield
      end
      read_sequence_end
    end

    # Iterates a mapping, yielding on each new entry until the mapping is
    # terminated.
    def each_in_mapping : Nil
      read_mapping_start
      until kind == YAML::EventKind::MAPPING_END
        yield
      end
      read_mapping_end
    end
  end
end
