class Product < ApplicationRecord
	has_many :images, dependent: :destroy

	def self.APIindex(userX)
		if userX&.class == User
			return `curl -H "bxxkxmxppAuthtoken: #{userX&.authentication_token}" -H "appName: #{ENV['appName']}"  -X GET #{SITEurl}/api/v1/products`
		else
			return `curl -H "appName: #{ENV['appName']}"  -X GET #{SITEurl}/api/v1/products`
		end
	end

	def self.APIshow(params)
		return `curl -H "appName: #{ENV['appName']}"  -X GET #{SITEurl}/api/v1/products/prod_#{params[:id]}?connectAccount=#{params[:connectAccount]}`
	end

	def self.APIcreate(userX, productParams)
		productName = productParams[:name].html_safe
		description = productParams[:description].html_safe
		type = productParams[:type]
		keywords = productParams[:keywords]
		stockCount = productParams[:stockCount].to_i

		images = []

		if !productParams['images'].blank?
			productParams['images'].each do |img|
				
				cloudX = Cloudinary::Uploader.upload(img.tempfile)
				images.append(cloudX['secure_url'])
			end
		end

		if userX&.class == User
			callIt = `curl -H "appName: #{ENV['appName']}" -H "bxxkxmxppAuthtoken: #{userX&.authentication_token}"  -d 'stockCount=#{stockCount}keywords=#{keywords}&images=#{images.join(",")}&type=#{type}&name=#{productName}&description=#{description}&connectAccount=#{userX&.stripeMerchantID}&active=true' -X POST #{SITEurl}/api/v1/products`
			response = Oj.load(callIt)

			return callIt
		end
	end

	def self.APIupdate(userX, productParams)
		productName = productParams[:name].html_safe
		description = productParams[:description].html_safe
		type = productParams[:type]
		keywords = productParams[:keywords]
		active = ActiveModel::Type::Boolean.new.cast(productParams[:active])
		stockCount = productParams[:stockCount].to_i

		images = []

		if !productParams['images'].blank?
			productParams['images'].each do |img|
				
				cloudX = Cloudinary::Uploader.upload(img.tempfile)
				images.append(cloudX['secure_url'])
			end
		end

		if userX&.class == User
			return `curl -H "appName: #{ENV['appName']}" -H "bxxkxmxppAuthtoken: #{userX&.authentication_token}"  -d "stockCount=#{stockCount}images=#{images.join(",")}&keywords=#{keywords}&name=#{productName}&description=#{description}&active=#{active}&type=#{type}&connectAccount=#{userX&.stripeMerchantID}" -X PATCH #{SITEurl}/api/v1/products/#{productParams[:id]}`
		end
	end
end
