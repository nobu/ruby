# rbs_inline: enabled
# frozen_string_literal: true

module Lrama
  class Lexer
    class Location
      attr_reader :grammar_file #: GrammarFile
      attr_reader :first_line #: Integer
      attr_reader :first_column #: Integer
      attr_reader :last_line #: Integer
      attr_reader :last_column #: Integer

      # @rbs (grammar_file: GrammarFile, first_line: Integer, first_column: Integer, last_line: Integer, last_column: Integer) -> void
      def initialize(grammar_file:, first_line:, first_column:, last_line:, last_column:)
        @grammar_file = grammar_file
        @first_line = first_line
        @first_column = first_column
        @last_line = last_line
        @last_column = last_column
      end

      # @rbs (Location other) -> bool
      def ==(other)
        self.class == other.class &&
        self.grammar_file == other.grammar_file &&
        self.first_line == other.first_line &&
        self.first_column == other.first_column &&
        self.last_line == other.last_line &&
        self.last_column == other.last_column
      end

      # @rbs (Integer left, Integer right) -> Location
      def partial_location(left, right)
        offset = -first_column
        new_first_line = -1
        new_first_column = -1
        new_last_line = -1
        new_last_column = -1

        _text.each.with_index do |line, index|
          new_offset = offset + line.length + 1

          if offset <= left && left <= new_offset
            new_first_line = first_line + index
            new_first_column = left - offset
          end

          if offset <= right && right <= new_offset
            new_last_line = first_line + index
            new_last_column = right - offset
          end

          offset = new_offset
        end

        Location.new(
          grammar_file: grammar_file,
          first_line: new_first_line, first_column: new_first_column,
          last_line: new_last_line, last_column: new_last_column
        )
      end

      # @rbs () -> String
      def to_s
        "#{path} (#{first_line},#{first_column})-(#{last_line},#{last_column})"
      end

      # @rbs (String error_message) -> String
      def generate_error_message(error_message)
        <<~ERROR.chomp
          #{path}:#{first_line}:#{first_column}: #{error_message}
          #{line_with_carets}
        ERROR
      end

      # @rbs () -> String
      def line_with_carets
        <<~TEXT
          #{text}
          #{carets}
        TEXT
      end

      private

      # @rbs () -> String
      def path
        grammar_file.path
      end

      # @rbs () -> String
      def blanks
        (text[0...first_column] or raise "#{first_column} is invalid").gsub(/[^\t]/, ' ')
      end

      # @rbs () -> String
      def carets
        blanks + '^' * (last_column - first_column)
      end

      # @rbs () -> String
      def text
        @text ||= _text.join("\n")
      end

      # @rbs () -> Array[String]
      def _text
        @_text ||=begin
          range = (first_line - 1)...last_line
          grammar_file.lines[range] or raise "#{range} is invalid"
        end
      end
    end
  end
end
