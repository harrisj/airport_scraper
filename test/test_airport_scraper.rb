require 'helper'
require 'yaml'

CA_TESTS = YAML.load_file(File.join(File.dirname(__FILE__), "ca_airports_tests.yml"))
US_TESTS = YAML.load_file(File.join(File.dirname(__FILE__), "us_airports_tests.yml"))
INTL_TESTS = YAML.load_file(File.join(File.dirname(__FILE__), "intl_airports_tests.yml"))

class TestAirportScraper < Test::Unit::TestCase
  context "new" do
    setup do
      @scrape = AirportScraper.new
    end
    
    should "load the airports.yml file into @airports" do
      airports = @scrape.airports
      assert_not_nil airports
      assert_not_nil airports['JFK'], "Didn't find JFK in airports"
    end
    
    should_eventually "create an @code_match_regex to match 3-letter codes" do
      code_regex = @scrape.instance_variable_get("@code_match_regex")
      assert_not_nil(code_regex)
      assert_match(code_regex, 'JFK')
      assert_no_match(code_regex, 'JFKX')
      assert_no_match(code_regex, 'jfk')
    end
    
    should_eventually "create an @airport_regex" do
      name_regex = @scrape.instance_variable_get("@airport_regex")
      assert_not_nil(name_regex)
      assert_match(name_regex, "Heathrow")
      assert_match(name_regex, "heathrow")
      assert_no_match(name_regex, "HeathrowX")
    end
    
    should "create an @matcher_prefixes array" do
      by_priority = @scrape.instance_variable_get("@matcher_prefixes")
      assert_not_nil(by_priority)
    end
    
    should "order @matcher_prefixes values in descending match_priority order" do
      # Check that PWM comes before PDX
      pref = @scrape.instance_variable_get("@matcher_prefixes")
      by_priority = pref[@scrape.prefix_from_match("Portland")]
      
      assert_not_nil by_priority
      pdx = by_priority.detect {|x| x['code'] == 'PDX'}
      pwm = by_priority.detect {|x| x['code'] == 'PWM'}
      
      pdx_idx = by_priority.index(pdx)
      pwm_idx = by_priority.index(pwm)
      assert_not_nil pdx_idx
      assert_not_nil pwm_idx
      
      assert(pwm_idx < pdx_idx)
    end
  end
  
  context "possible_flight" do
    setup do
      @scrape = AirportScraper.new
    end
    
    ["on a flight to Rome", "flying to SFO", "just touched down in Vegas", "EWR to NYC", "EWR -> NYC"].each do |phrase|
      should "return true for the phrase '#{phrase}'" do
        assert @scrape.possible_flight(phrase)
      end
    end
  end
  
  context "extract_airports" do
    setup do
      @scrape = AirportScraper.new
    end
    
    context "when there are no airports in the text" do
      should "return an empty_array" do
        assert_equal [], @scrape.extract_airports("Twas brillig and the slithy toves")
      end
    end
    
    context "Airport code tests" do
      setup do
        @scrape = AirportScraper.new
      end
      
      should_eventually "be able to match the airport codes" do
        @scrape.airports.each do |airport|
          assert_contains @scrape.extract_airports("Just landed in #{airport['code']}."), airport
        end
      end
    end
    
    context "Freeform name test" do
      [US_TESTS, CA_TESTS, INTL_TESTS].each do |tests|
        tests.keys.each do |code|
          tests[code].each do |str|
            should "return the airport #{code} for phrase '#{str}'" do
              airport = @scrape.airport(code)
              results = @scrape.extract_airports(str)
              assert_contains results, airport, "Expected #{code}, returned #{results.map {|x| x['code']}.inspect }"
            end
          end
        end
      end
    end    
  end
end
