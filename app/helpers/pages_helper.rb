require 'lib/ziptime.rb'

module PagesHelper

	# Main engine
	def run_main zip

		if zip.length != 5 || !numeric?(zip)		# Ensure the length of the zip code is five and it is numeric.
			return "Error"												# Otherwise, return an error
		else
			url = 'http://www.wunderground.com/cgi-bin/findweather/hdfForecast?query=' + zip		# Get the URL for Weather Undergrond
			@agent = Mechanize.new { |agent|																										# Start a mechanize agent
        agent.user_agent_alias = 'Mac Safari'
      }
			data = scrape(@agent, url)						# Scrape the data off the page (this will return an array)
		end
		data																		# Pass that array to the view
	end

	# Determine if a zipcode is numeric or not
	def numeric? zip
		if zip =~ /^\d+$/
			return true
		else
			false
		end
	end

	# Scrape the weather site for location and humidity data and return it in an array [location, humidity]
	def scrape agent, source
	  agent.get(source) do |page|														# Scrape the page
	  	@location = page / 'div#location' / 'h1'						# Get location data from the h1 in the location div
	  	@location = @location.children[0].text[3..-4]				# Get location text from the child and strip out wrapper

	  	@humidity = page / 'script'
	  	raise Time.new.hour.inspect
	  	raise @humidity[30].to_html.split('"iso8601":')[4].inspect
	  end
	  data['location'] = @location													# Put information into array
	  data['humidity'] = @humidity
	  data																									# Return array
	end

end
