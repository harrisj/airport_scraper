require 'yaml'

class AirportScraper
  attr_reader :airports, :airport_codes

  def initialize
    load_airports
    create_regexes
  end

  def regex_from_matchers(matchers)
    if matchers.nil? || matchers.empty?
      nil
    else
      /^(#{matchers.map {|x| x.gsub(".", "\\.")}.join('|')})\b/i
    end
  end

  def load_airports
    @airports = {}
    
    %w(ca_airports us_airports intl_airports).each do |file|
      @airports.merge!(YAML.load_file(File.join(File.dirname(__FILE__), "#{file}.yml")))
    end
    
    @matcher_prefixes = {}
    
    @airports.each do |key, value|
      value['code'] = key
      value['major'] ||= false
      value['match_priority'] ||= value['major'] ? 10 : 0
      value['name'] ||= value['city']
      value['matchers'] = case value['matchers']
        when nil
          []
        when Array
          value['matchers']
        else
          value['matchers'].to_a
      end
      
      value['regex'] = regex_from_matchers(value['matchers'])

      unless value['matchers'].nil?
        prefixes = value['matchers'].map {|x| prefix_from_match(x)}.uniq
        prefixes.each do |p| 
          @matcher_prefixes[p] ||= []
          @matcher_prefixes[p] << value
        end
      end
    end
    
    @airport_codes = @airports.keys

    @matcher_prefixes.values.each do |airports|
      airports.sort! {|a, b| b['match_priority'] <=> a['match_priority'] }
    end
    
#    raise @matcher_prefixes.inspect
  end
  
  def prefix_from_match(str)
    case str 
    when /\w\w\b/
      str[0,2].downcase
    else
      str[0,3].downcase
    end
  end

  def create_regexes
    @code_match_regex = /\b([A-Z]{3})\b/

    flight_regex = /(flight|flying|plane|jet|turboprop)(\s(back|again|over))?/i
    airport_regex = /(.+)/
    
    @trans_regex = /(\sto\s)|(\s?->\s?)|(\s?>\s?)|(\s?✈\s?)/
    @via_regex = /,?\s?(via|by way of|on route to)\s/

    @preposition_regex = /\bfrom\s|\bto\s|#{@via_regex}|#{@trans_regex}|\bin\s|\bat\s|@\s/i
    
    @match_regexes = [
      /((at|@|in) #{airport_regex} airport)/i,
      /((boarding|departing) (to|from|in) #{airport_regex})/i,
      /(touched down in #{airport_regex})\b/i,
      /((to land)|(land(ed|ing|s)) (in|at) #{airport_regex})\b/i,
      /(#{flight_regex}( (from|in|at|out of) #{airport_regex})? to #{airport_regex}(#{@via_regex}#{airport_regex})?)/i,
      /(#{@code_match_regex}(#{@trans_regex}#{@code_match_regex})+\b)/ # (#{@via_regex}#{@code_match_regex}\b)?)/i,
    ]
  end

  def airport(code)
    @airports[code]
  end
  
  def flight_terms
    %w(touched landed landing land lands plane jet turboprop flying flight boarding departing)
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
      if text =~ regex
        str = $1
        matches = str.split(@preposition_regex)
      
        # puts "MATCHES: #{matches.inspect}" unless matches.empty?
        # puts "Text: #{text}"
        # puts "Regex: #{regex.inspect}"
        matches.each do |match|
          next if match.nil? || match.length < 2

          if match =~ /^#{@code_match_regex}/
            #puts "MATCH: #{match}"
            airport = @airports[$1]
            airports << airport unless airport.nil?
          else
            possible_airports = @matcher_prefixes[prefix_from_match(match)]
            unless possible_airports.nil?
              possible_airports.each do |a|
                next if a['regex'].nil?
                if match =~ /#{a['regex']}\b/
                  airports << a
                  break
                end
              end
            end
          end
        end
        
        # break
      end
    end
    
    airports.uniq
  end
end