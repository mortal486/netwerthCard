class Service < ApplicationRecord

	def self.APIindex(userX)
		if userX&.class == User
			return `curl -H "appName: #{ENV['appName']}" -H "bxxkxmxppAuthtoken: #{userX&.authentication_token}" -X GET #{SITEurl}/v1/products`
		else
			return `curl -H "appName: #{ENV['appName']}" -X GET #{SITEurl}/v1/products`
		end
	end

	def self.APIshow(userX, params)
		if userX&.class == User
			return `curl -H "appName: #{ENV['appName']}" -H "bxxkxmxppAuthtoken: #{userX&.authentication_token}" -X GET #{SITEurl}/v1/products/prod_#{params[:id]}?connectAccount=#{params[:connectAccount]}`
		end
	end

	def self.APIcreate(userX, productParams)
		productName = productParams[:name]
		description = productParams[:description]
		type = productParams[:type]
		keywords = productParams[:keywords]

		images = []
		productStarted = Product.create()

		if !productParams['images'].blank?
			productParams['images'].each do |img|
				imageMade = productStarted.images.create(source: img)
				cloudX = Cloudinary::Uploader.upload(imageMade.source.file.file)
				images.append(cloudX['secure_url'])
				File.delete(imageMade.source.file.file)
			end
		end

		if userX&.class == User
			callIt = `curl -H "appName: #{ENV['appName']}" -d 'keywords=#{keywords}&images=#{images.join(",")}&type=#{type}&name=#{productName}&description=#{description}&connectAccount=#{userX&.stripeMerchantID}&active=true' -H "bxxkxmxppAuthtoken: #{userX&.authentication_token}" -X POST #{SITEurl}/v1/products`
			response = Oj.load(callIt)
			productStarted.update(stripeProductID: response['product'])

			return callIt
		end
	end

	def self.APIupdate(userX, productParams)
		productName = productParams[:name]
		description = productParams[:description]
		type = productParams[:type]
		keywords = productParams[:keywords]
		active = ActiveModel::Type::Boolean.new.cast(productParams[:active])

		images = []

		if !productParams['images'].blank?
			productParams['images'].each do |img|
				productFound = Product.find_by(stripeProductID: productParams[:id])
				imageMade = productFound.images.create(source: img)
				
				cloudX = Cloudinary::Uploader.upload(imageMade.source.file.file)
				images.append(cloudX['secure_url'])
				File.delete(imageMade.source.file.file)
			end
		end

		if userX&.class == User
			return `curl -H "appName: #{ENV['appName']}" -d "images=#{images.join(",")}&keywords=#{keywords}&name=#{productName}&description=#{description}&active=#{active}&type=#{type}&connectAccount=#{userX&.stripeMerchantID}" -H "bxxkxmxppAuthtoken: #{userX&.authentication_token}" -X PATCH #{SITEurl}/v1/products/#{productParams[:id]}`
		end
	end

	def self.APIdestroy(userX)
		if userX&.class == User
			return `curl -H "appName: #{ENV['appName']}" -H "bxxkxmxppAuthtoken: #{userX&.authentication_token}" -X GET #{SITEurl}/v1/products`
		end
	end
end
