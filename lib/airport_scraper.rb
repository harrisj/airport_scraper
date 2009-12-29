require 'yaml'

class AirportScraper
  attr_reader :airports

  def initialize
    load_airports
    create_regexes
  end

  def regex_from_matchers(matchers)
    if matchers.nil? || matchers.empty?
      nil
    else
      /#{matchers.map {|x| x.gsub(".", "\\.")}.join('|')}/i
    end
  end

  def load_airports
    @airports = {}
    
    %w(ca_airports us_airports intl_airports).each do |file|
      @airports.merge!(YAML.load_file(File.join(File.dirname(__FILE__), "#{file}.yml")))
    end
    
    @airports.each do |key, value|
      value['code'] = key
      value['match_priority'] ||= 0
      value['regex'] = regex_from_matchers(value['matchers'])
    end
    
    @airport_codes = @airports.keys
  end

  def create_regexes
    @code_regex = /#{@airport_codes.join('|')}/

    @airports_by_priority = @airports.values.sort {|a, b| b['match_priority'] <=> a['match_priority'] }

    @name_regex = /#{@airports_by_priority.map{|x| x['regex']}.join("|")}/i
    
    @code_match_regex = /(#{@code_regex})/
    
    @airport_regex = /(#{@code_regex}|#{@name_regex})/
    
    # puts @airport_regex.inspect
    #@name_matchers = @airports.values.sort {|a,b| a['match_priority'].to_i > b['match_priority'].to_i}.map {|a| /^(#{a['matchers'].join("|")]

    @transition_regex = /\sto\s|\s?->\s?|\s?>\s|\s?✈\s?/
    @via_regex = /,?(via|by way of)\s/

    @match_regexes = [
      /touched down in #{@airport_regex}\b/i,
      /land(ed|ing)? (in|at) #{@airport_regex}\b/i,
      /on a plane to #{@airport_regex}\b/i,
      /on a plane from #{@airport_regex} to #{@airport_regex}\b/i,
      /flight to #{@airport_regex}\b/i,
      /flying ((back|again) )?(from #{@airport_regex} )?to #{@airport_regex}\b/i,
      /#{@code_match_regex}(#{@transition_regex}#{@code_match_regex})+\b/ #(#{@via_regex}#{@code_match_regex}\b)?/i,
    ]


    #@regex = /#{@match_regexes.map {|m| /(#{m})/ }.join("|")}/
  end

  def airport(code)
    @airports[code]
  end

  def possible_flight(text)
    text =~ /(touched down in)|(land(ing|ed)? (in|at))|(on a plane to)|(on a plane from)|((flying|flight) (from|to))|(\b[A-Z]{3} (to|->) [A-Z]{3}\b)/i
  end

  def is_flight(text)
    true
  end

  def extract_airports(text)
    airports = [] 
    
    #puts @airport_regex.inspect

    @match_regexes.each do |regex|
      # puts regex.inspect
      matches = text.scan(regex)
      
      # puts "Text: #{text}"
      # puts "Regex: #{regex.inspect}"
      # puts "Matches #{matches.inspect}"
    
      matches.flatten.each do |match|
        if match =~ /^#{@code_regex}/
          # puts "MATCH: #{match}"          
          airports << @airports[match]
        else
          @airports_by_priority.each do |a|
            next if a['regex'].nil?
            if match =~ /#{a['regex']}\b/
              airports << a
              break
            end
          end
        end
      end
    end
    
    airports.uniq
  end
end