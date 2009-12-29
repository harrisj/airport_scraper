require 'helper'
require 'yaml'

SINGLE_TESTS = YAML.load_file(File.join(File.dirname(__FILE__), "single_tests.yml"))

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
    
    should "create an @airports_by_priority array" do
      by_priority = @scrape.instance_variable_get("@airports_by_priority")
      assert_not_nil(by_priority)
    end
    
    should "order in descending match_priority order" do
      # Check that PWM comes before PDX
      by_priority = @scrape.instance_variable_get("@airports_by_priority")
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
    
    context "single airport examples" do      
      SINGLE_TESTS.keys.each do |code|
        SINGLE_TESTS[code].each do |str|
          should "return the airport #{code} for phrase '#{str}'" do
            airport = @scrape.airport(code)
            assert_contains @scrape.extract_airports(str), airport
          end
        end
      end
    end
  end
end
