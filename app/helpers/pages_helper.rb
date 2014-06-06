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

	  	@data = {}																																				# Initialize hash
			@data['location'] = location

			for day in 0..6
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
					rise_data = get_rises_and_sets(page, day)
					for hour in @now+1..23
						run_main(page, day, hour, moon_data, rise_data)
					end

				else
					@data[day]['label'] = (Date.today + day.days).strftime("%e %B %Y")
					moon_data = get_moon_phase(day)
					rise_data = get_rises_and_sets(page, day)
					for hour in 0..23
						run_main(page, day, hour, moon_data, rise_data)
					end
				end
			
			end
		end

	  @data																																								# Return hash
	end


	# Wrapper function
	def run_main page, day, hour, moon_data, rise_data
		@data[day][hour] = {}																																# Initialize hash
		@data[day][hour]['phase_day'] = moon_data[0]																				# Import moon data
		@data[day][hour]['phase_name'] = moon_data[1]
		
		@data[day][hour]['sunset'] = rise_data[0]
		@data[day][hour]['sunrise'] = rise_data[1]
		@data[day][hour]['moonset'] = rise_data[2]
		@data[day][hour]['moonrise'] = rise_data[3]

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


	# Get sunrise, sunset, moonrise, and moonset
	def get_rises_and_sets page, day
		astro = page / 'script'																															# Look into page JavaScripts
  	astro = astro[30].to_html.split('"astronomy":')[1].split('length_of_day')						# Grab the data section from JavaScripts
  	jumps = day + 1

  	sunset_pos = astro[jumps].index('sunset')																						# Get sunset
  	sunset = astro[jumps][sunset_pos+57..sunset_pos+64].gsub(/[^0-9A-Z:]/,'')
  	
  	sunrise_pos = astro[jumps].index('sunrise')																					# Get sunrise
  	sunrise = astro[jumps][sunrise_pos+57..sunrise_pos+64].gsub(/[^0-9A-Z:]/,'')

  	moonset_pos = astro[jumps].index('moonset')																					# Get moonset
  	moonset = astro[jumps][moonset_pos+57..moonset_pos+64].gsub(/[^0-9A-Z:]/,'')

  	moonrise_pos = astro[jumps].index('moonrise')																				# Get moonrise
  	moonrise = astro[jumps][moonrise_pos+57..moonrise_pos+65].gsub(/[^0-9A-Z:]/,'')

	  [sunset, sunrise, moonset, moonrise]																								# Return data
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


	# Score the hour for stargazing quality on an 100 point scale
	def score! day, time
		# Sunset score
		### 0-40 determined by sun
		### ...sunset is 10
		### ...sunset+1 is 35
		### ...sunset+2 is 45
		### ...sunset+3 is 50
		sunset_score = 0
		if time <= @data[day][time]['sunrise'].to_i or (@data[day][time]['sunset'].to_i + 12) <= time then sunset_score = 10 end
		if time <= (@data[day][time]['sunrise'].to_i - 1) or (@data[day][time]['sunset'].to_i + 13) <= time then sunset_score = 35 end
		if time <= (@data[day][time]['sunrise'].to_i - 2) or (@data[day][time]['sunset'].to_i + 14) <= time then sunset_score = 45 end
		if time <= (@data[day][time]['sunrise'].to_i - 3) or (@data[day][time]['sunset'].to_i + 15) <= time then sunset_score = 50 end
	  @data[day][time]['sunset_score'] = sunset_score

	  # Moon phase score
	  ### 0-25 determined by moon
		### ...full is 0
		### ...new is 25
	  moonrise_t = @data[day][time]['moonrise']
	  moonrise = moonrise_t.to_i
	  if moonrise_t.last(2) == "PM" then moonrise += 12 end
	  moonset_t = @data[day][time]['moonset']
	  moonset = moonset_t.to_i
	  if moonset_t.last(2) == "PM" then moonset += 12 end
	  if moonrise < moonset then interval = (moonrise+1..moonset-1)
	  else interval = (moonset+1..moonrise-1) end
	  if interval.include?(time)
	  	moon_phase_score = 15
	  else
		  phase = @data[day][time]['phase_day']
		  moon_phase_score = (15 - phase).abs
		end
		@data[day][time]['moon_phase_score'] = (moon_phase_score*(5/3)).round

		# Humidity score
		### 0-10 determined by humidity
		### ...10*humidity
		humidity_score = @data[day][time]['humidity'].to_f
		@data[day][time]['humidity_score'] = (10*((100-humidity_score)/100)).round

		# Cloud cover score
		### 0-25 determined by cloudcover
		### ...25*cloudcover
		cloud_cover_score = @data[day][time]['cloud_cover'].to_f
		@data[day][time]['cloud_cover_score'] = (25*((100-cloud_cover_score)/100)).round

		# Total score
		if sunset_score == 0 then total_score = 0
		else total_score = sunset_score + moon_phase_score*(5/3) + 10*((100-humidity_score)/100) + 25*((100-cloud_cover_score)/100) end
		@data[day][time]['total_score'] = total_score
	end


end
