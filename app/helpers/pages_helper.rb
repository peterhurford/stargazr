require 'ziptime'

module PagesHelper	

	# Main engine
	def run_main zip
		if zip.length != 5																		# Ensure zip code is five digits or return error
			return "Error: Zip code must be five digits."
		elsif !numeric?(zip)																	# Ensure zip code is numeric or return error
			return "Error: Zip code must be numeric."
		elsif !zipcode?(zip)																	# Ensure zip code exists or return error
			return "Error: Zip code doesn't exist."
		else
			data = scrape(zip)																	# Scrape the data off the page (this will return an array)
		end
		data																									# Pass that array to the view
	end


	# Determine if a zipcode is numeric or not
	def numeric? zip
		if zip =~ /^\d+$/
			true
		else
			false
		end
	end


	# Check if zipcode exists
	def zipcode? zip
		ziptime = Ziptime::ZIPTIME 														# Get ziptime data from library
		if ziptime.include? zip
			true
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

	  agent.get(url) do |page|																					# Scrape the page

	  	# Get Location Data
	  	location = page / 'div#location' / 'h1'													# Get location data from the h1 in the location div
	  	location = location.children[0].text[3..-4]											# Get location text from the child and strip out wrapper

	  	moonphase = page / 'div.moonNorth'															# Get moon phase
	  	moonphase =  moonphase.children[1].children[0].text

	  	sunset = page / 'div#curAstronomy'															# Get sunset time
	  	sunset = sunset.children[1].children[3].children[2].text

		  # Return data
		  @data = {}																											# Initialize hash
		  ziptime = Ziptime::ZIPTIME 																			# Get ziptime data from library
		  @data['offset'] = ziptime[zip][0]
			@data['dst'] = ziptime[zip][1]
			@data['location'] = location
			@data['moonphase'] = moonphase
			@data['sunset'] = sunset

			for day in 0..9
				@data[day] = {}
				
				if day == 0
					@data[day]['label'] = Date.today.strftime("%e %B %Y")
					now = Time.new.hour
					for hour in now+1..23
						@data[day][hour] = {}
						get_weather!(page, day, hour)																# Fetch weather for all relevant times and add it to data
					end

				else
					@data[day]['label'] = (Date.today + day.days).strftime("%e %B %Y")
					for hour in 0..23
						@data[day][hour] = {}
						get_weather!(page, day, hour)																# Fetch weather for all relevant times and add it to data
					end
				end
			
			end
		end

	  @data																															# Return hash
	end


	def get_weather! page, day, time 					# Expect day is a number 0-1 indicating days from today
																						# time is a number 0-24 indicating the hour of the day

		hour = Time.new.hour																															# Get current hour
		to_hour = time - hour																															# Get distance from now to target hour
		jumps = to_hour + 3 																															# Add 3 because we need to jump over three elements
		jumps = 25*day + jumps																														# Adjust for day

  	# TODO: Get moon phase
  	# TODO: Get sunset
  	# TODO: Handle different timezones and DST
  	# TODO: Only get times for after sunset
  	# TODO: Get multiple days

		weather = page / 'script'																														# Look into page JavaScripts
  	weather = weather[30].to_html.split('"iso8601":')[jumps]														# Grab the 10PM data section from JavaScripts
  	#if day == 1 and time == 1 then raise [day, time, jumps, weather].inspect end
  	
  	humidity_pos = weather.index('humidity')																						# Get humidity
  	humidity = weather[humidity_pos+11..humidity_pos+12]
  	cloud_cover_pos = weather.index('cloudcover')																				# Get cloud cover
  	cloud_cover = weather[cloud_cover_pos+13..cloud_cover_pos+14]
  	temperature_pos = weather.index('temperature')																			# Get temperature
  	temperature = weather[temperature_pos+14..temperature_pos+15]
  	precipitation_pos = weather.index('pop')																						# Get precipitation
  	precipitation = weather[precipitation_pos+5..precipitation_pos+7]
  	wind_pos = weather.index('wind_speed')																							# Get wind
  	wind = weather[wind_pos+12..wind_pos+13]

  	@data[day][time]['label'] = time
  	# TODO: Format time better
  	@data[day][time]['humidity'] = humidity.gsub(/[^0-9]/,'')														# Add data.  Also, format by removing nonnumeric info.
	  @data[day][time]['cloud_cover'] = cloud_cover.gsub(/[^0-9]/,'')
	  @data[day][time]['temperature'] = temperature.gsub(/[^0-9]/,'')
	  @data[day][time]['precipitation'] = precipitation.gsub(/[^0-9]/,'')
	  @data[day][time]['wind'] = wind.gsub(/[^0-9]/,'')
	end

end
