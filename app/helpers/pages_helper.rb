require 'ziptime'

module PagesHelper	

	# Main engine
	def engine zip
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

	  agent.get(url) do |page|																														# Scrape the page

	  	# Get Location Data
	  	location = page / 'div#location' / 'h1'																						# Get location data from the h1 in the location div
	  	location = location.children[0].text[3..-4]																				# Get location text from the child and strip out wrapper

	  	sunset = page / 'div#curAstronomy'																								# Get sunset time
	  	sunset = sunset.children[1].children[3].children[2].text

	  	sunrise = page / 'div#curAstronomy'																								# Get sunrise time
	  	sunrise = sunrise.children[1].children[1].children[2].text

		  # Return data
		  @data = {}																																				# Initialize hash
			@data['location'] = location
			@data['sunset'] = sunset
			@data['sunrise'] = sunrise

			for day in 0..8
				@data[day] = {}
				
				if day == 0
					ziptime = Ziptime::ZIPTIME 																										# Get ziptime data from library
					offset = ziptime[zip][0]
					dst = ziptime[zip][1]
					if Time.now.dst? and dst == 0 then offset = offset - 1 end

					if offset == -5
						@data[day]['label'] = Date.today.strftime("%e %B %Y")
						@now = Time.new.hour
					else
						offset = offset + 5
						@data[day]['label'] = (Date.today + offset.hours).strftime("%e %B %Y")
						@now = Time.new.hour + offset
						if @now < 0 then @now = @now + 24 end
					end
					
					moon_data = get_moon_phase(day)																								# Calculate moon data
					for hour in @now+1..23
						run_main(moon_data, page, day, hour)
					end

				else
					@data[day]['label'] = (Date.today + day.days).strftime("%e %B %Y")
					moon_data = get_moon_phase(day)
					for hour in 0..23
						run_main(moon_data, page, day, hour)
					end
				end
			
			end
		end

	  @data																																								# Return hash
	end


	# Wrapper function
	def run_main moon_data, page, day, hour
		@data[day][hour] = {}																																# Initialize hash
		@data[day][hour]['phase_day'] = moon_data[0]																				# Import moon data
		@data[day][hour]['phase_name'] = moon_data[1]
		get_weather!(page, day, hour)																												# Fetch weather for all relevant times and impute it to data hash
		score!(day, hour)																																		# Impute a score to data hash
	end


	# Function to read weather data
	def get_weather! page, day, time 					# Expect day is a number 0-9 indicating days from today
																						# time is a number 0-23 indicating the hour of the day

		to_hour = time - @now																																# Get distance from now to target hour
		jumps = to_hour + 3 																																# Add 3 because we need to jump over three bogus elements in the beginnign
		if time == 0 then jumps += 2 end																										# Don't know why this is necessary
		jumps += 25*day																																			# Adjust for day

  	# Get weather data
		weather = page / 'script'																														# Look into page JavaScripts
  	weather = weather[30].to_html.split('"iso8601":')[jumps]														# Grab the data section from JavaScripts
  	
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

  	@data[day][time]['humidity'] = humidity.gsub(/[^0-9]/,'')														# Add data.  Also, format by removing nonnumeric info.
	  @data[day][time]['cloud_cover'] = cloud_cover.gsub(/[^0-9]/,'')
	  @data[day][time]['temperature'] = temperature.gsub(/[^0-9]/,'')
	  @data[day][time]['precipitation'] = precipitation.gsub(/[^0-9]/,'')
	  @data[day][time]['wind'] = wind.gsub(/[^0-9]/,'')

	  # Get time label
	  if time == 0
	  	t_label = "12AM"
	  elsif time < 12
	  	t_label = "#{time}AM"
	  elsif time == 12
	  	t_label = "#{time}PM"
	  else
	  	timetmp = time - 12
	  	t_label = "#{timetmp}PM"
	  end
	  @data[day][time]['label'] = t_label
	  offset = Time.new.hour - @now
	  @data[day][time]['timestamp'] = Time.new.beginning_of_hour + day.days + time.hours - Time.new.hour.hours - offset.hours
	end


	# Translate moon data from moon calculation
	def get_moon_phase day
		ftime = Time.now + day.days
		phase_day = calculate_moon(ftime.day, ftime.month, ftime.year)											# Get phase day (0-29)
	
  	phase_name = "New Moon"																															# Get phase name from phase day
  	if 2 <= phase_day and phase_day <= 6 then phase_name = "Waxing Crescent"
  	elsif 7 <= phase_day and phase_day <= 9 then phase_name = "First Quarter"
  	elsif 10 <= phase_day and phase_day <= 13 then phase_name = "Waxing Gibbous"
  	elsif 14 <= phase_day and phase_day <= 16 then phase_name = "Full Moon"
  	elsif 14 <= phase_day and phase_day <= 16 then phase_name = "Waning Gibbous"
  	elsif 14 <= phase_day and phase_day <= 16 then phase_name = "Last Quarter"
  	else phase_name = "Waning Crescent" end

  	[phase_day, phase_name]																															# Return an array with the phase day and phase name
  end


  # Calculate moon phase
	def calculate_moon day, month, year
		# Conway method adapted from http://www.ben-daglish.net/moon.shtml
		# Note: will need a new method if this app is still around in the 22nd century
		r = year % 100;
		r %= 19;
		if r > 9 then r -= 19 end
		r = ((r * 11) % 30) + month + day
		if month < 3 then r += 2 end
		r -= ((year<2000) ? 4 : 8.3)
		r = ((r+0.5)%30).floor
		return (r < 0) ? r+30 : r 						# Returns phase day (0 to 29, where 0=new moon, 15=full etc.)
	end


	# Score the hour for stargazing quality
	def score! day, time
		# Sunset score
	  sunset_hour = @data['sunset'][0].to_i + 12
	  sunrise_hour = @data['sunrise'][0].to_i
	  sunset_score = 0
	  unless (sunrise_hour..sunset_hour).include?(time) then sunset_score = 1 end
	  unless (sunrise_hour-1..sunset_hour+1).include?(time) then sunset_score = 1.5 end
	  unless (sunrise_hour-2..sunset_hour+2).include?(time) then sunset_score = 2 end
	  @data[day][time]['sunset_score'] = sunset_score*50

	  # Moon phase score
	  phase = @data[day][time]['phase_day']
	  moon_phase_score = (15 - phase).abs
		@data[day][time]['moon_phase_score'] = moon_phase_score*3

		# Humidity score
		humidity_score = @data[day][time]['humidity'].to_f
		@data[day][time]['humidity_score'] = (100-humidity_score)/2

		# Cloud cover score
		cloud_cover_score = @data[day][time]['cloud_cover'].to_f
		@data[day][time]['cloud_cover_score'] = 100-cloud_cover_score

		# Total score
		if sunset_score == 0 then total_score = 0
		else total_score = sunset_score*50 + 100-cloud_cover_score + (100-humidity_score)/2 + moon_phase_score*3 end
		@data[day][time]['total_score'] = total_score
	end


end
