#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(__dir__, "lib"))
require "grouper"

VALID_MATCHERS = %w[same_email same_phone same_email_or_phone].freeze

def usage
  <<~HELP
    Usage: ruby grouper.rb <input.csv> <matching_type>

    matching_type must be one of:
      same_email            – match rows that share any email address
      same_phone            – match rows that share any phone number
      same_email_or_phone   – match rows that share an email OR a phone number

    Example:
      ruby grouper.rb input1.csv same_email_or_phone
  HELP
end

if ARGV.length != 2
  warn usage
  exit 1
end

input_path, matching_type = ARGV

unless File.exist?(input_path)
  warn "Error: file not found: #{input_path}"
  exit 1
end

unless VALID_MATCHERS.include?(matching_type)
  warn "Error: unknown matching type '#{matching_type}'"
  warn usage
  exit 1
end

puts Grouper.process(input_path, matching_type.to_sym)
