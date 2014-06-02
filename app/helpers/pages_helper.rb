module PagesHelper

	def run_main(zip)
		if zip.length != 5 || !numeric?(zip)
			return "Error"
		else
			data = 'http://www.wunderground.com/cgi-bin/findweather/hdfForecast?query=' + zip
		end
		data
	end

	def numeric?(zip)
		if zip =~ /^\d+$/
			return true
		else
			false
		end
	end

end
