require 'ziptime'

module PagesHelper	

	# Main engine
	def run_main zip
		if zip.length != 5 || !numeric?(zip)		# Ensure the length of the zip code is five and it is numeric.
			return "Error"												# Otherwise, return an error
		else
			data = scrape(zip)										# Scrape the data off the page (this will return an array)
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
	def scrape zip

		url = 'http://www.wunderground.com/cgi-bin/findweather/hdfForecast?query=' + zip		# Get the URL for Weather Undergrond
		agent = Mechanize.new { |agent|																										  # Start a mechanize agent
      agent.user_agent_alias = 'Mac Safari'
    }

	  agent.get(url) do |page|															# Scrape the page

	  	# Get Location Data
	  	@location = page / 'div#location' / 'h1'						# Get location data from the h1 in the location div
	  	@location = @location.children[0].text[3..-4]				# Get location text from the child and strip out wrapper

	  	# Get correct table for weather data
	  	hour = Time.new.hour																								# Get current hour
	  	to_ten_pm = 22 - hour																								# Get distance from now to 10PM
	  	jumps = to_ten_pm + 3 																							# Add 3 because we need to jump over three elements
	  	@weather = page / 'script'																					# Look into page JavaScripts
	  	@weather = @weather[30].to_html.split('"iso8601":')[jumps]					# Grab the 10PM data section from JavaScripts
	  	humidity_pos = @weather.index('humidity')														# Get humidity
	  	@humidity = @weather[humidity_pos+11..humidity_pos+12]
	  	cloud_cover_pos = @weather.index('cloudcover')											# Get cloud cover
	  	@cloud_cover = @weather[cloud_cover_pos+13..cloud_cover_pos+14]
	  	temperature_pos = @weather.index('temperature')											# Get temperature
	  	@temperature = @weather[temperature_pos+14..temperature_pos+15]
	  	precipitation_pos = @weather.index('pop')														# Get precipitation
	  	@precipitation = @weather[precipitation_pos+5..precipitation_pos+7]
	  end

	  # Return data
	  data = {}																		# Initialize hash
	  ziptime = Ziptime::ZIPTIME 									# Get ziptime data from library
	  data['humidity'] = @humidity
	  data['cloud_cover'] = @cloud_cover
	  data['temperature'] = @temperature
	  data['precipitation'] = @precipitation
		data['offset'] = ziptime[zip][0]
		data['dst'] = ziptime[zip][1]
	  data['location'] = @location
	  data['humidity'] = @humidity
	  data																				# Return hash
	end


end
