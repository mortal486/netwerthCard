class ApplicationController < ActionController::Base
	before_action :configure_permitted_parameters, if: :devise_controller?

	def pullCustomers
		callCurl = current_user&.indexStripeCustomerAPI(params)

		if callCurl['success']
			
			session[:fetchedCustomers] = callCurl['customers']['data']
			session[:pendingCustomersHasMore] = callCurl['has_more']	

		end
	end

	def pullCharges
		curlCall = current_user&.indexStripeChargesAPI(params)
	  response = Oj.load(curlCall)
	  
	  if response['success']
			session[:fetchedCharges] = response['charges']
			session[:chargesHasMore] = response['has_more']	
    end
	end

	def pullOrders
		curlCall = current_user&.indexStripeOrdersAPI(params)
  	response = Oj.load(curlCall)
				

    if response['success']
			session[:fetchedPendingOrders] = response['orders']
			session[:pendingOrdersHasMore] = response['has_more']
		end
	end

	def pullSchedule
		curlCall = current_user&.indexStripeScheduleAPI(params)
  	response = Oj.load(curlCall)
				
    if response['success']
			session[:fetchedPendingServices] = response['services']
			session[:pendingServicesHasMore] = response['has_more']
		end
	end

	def stripeCheckoutRequest(lineItems,customer)
		
		paramsX = {
			"customer" => customer,
			"type" => @shippable == true ? "good" : 'service' ,
			"lineItems" => lineItems,
			"amount" => @jsonAmount,
			"application_fee_amount" => @application_fee_amount
		}.to_json

    curlCall = `curl -H "Content-Type: application/json" -H "appName: #{ENV['appName']}" -d '#{paramsX}' -X POST #{SITEurl}/api/v2/invoices`
    
	  response = Oj.load(curlCall)
	end

	def stripeCustomerRequest(token, connectAccount)
		if (customerExists = Stripe::Customer.list({limit: 1, email: session[:email]}, {stripe_account: connectAccount})['data'][0]) && !customerExists.blank?

			updated = Stripe::Customer.update(
				customerExists['id'],{
			   	source: token['id']
			  }, {stripe_account: connectAccount
			})
			
			connectAccountCus = customerExists
		else
			connectAccountCus = Stripe::Customer.create({
				email: session[:email],
				name: session[:name],
				phone: session[:phone],
				address: session[:address],
			  source: token['id']
			}, {stripe_account: connectAccount})
		end

		return connectAccountCus
	end

	def stripeTokenRequest(newStripeCardTokenParams,connectAccount)
		number = newStripeCardTokenParams[:number]
    exp_year = newStripeCardTokenParams[:exp_year]
    exp_month = newStripeCardTokenParams[:exp_month]
    cvc = newStripeCardTokenParams[:cvc]

    if connectAccount.present?
	    curlCall = `curl -H "appName: #{ENV['appName']}" -d "connectAccount=#{connectAccount}&number=#{number}&exp_month=#{exp_month}&exp_year=#{exp_year}&cvc=#{cvc}" #{SITEurl}/api/v2/tokens`
	  else
	    curlCall = `curl -H "appName: #{ENV['appName']}" -d "number=#{number}&exp_month=#{exp_month}&exp_year=#{exp_year}&cvc=#{cvc}" #{SITEurl}/api/v2/tokens`
	  end

    response = Oj.load(curlCall)
	end

	def pullChargesAPI
		curlCall = current_user&.indexStripeChargesAPI(params)
			
	  response = Oj.load(curlCall)

    if response['success']
			session[:payments] = response['payments']
			session[:pending] = response['pending']
		elsif response['message'] == "No purchases found"
			@message = response['message']
		else
			flash[:error] = response['message']
		end
	end

	def grabCart
		if current_user&.authentication_token
			curlCall = `curl -H "appName: #{ENV['appName']}" -H "bxxkxmxppAuthtoken: #{current_user.authentication_token}" -X GET #{SITEurl}/api/v1/carts`
			
	    response = Oj.load(curlCall)
	    
	    if response['success']
	    	@cart = response.merge(stripeCapturePercentage: ENV['stripeCapturePercentage'].to_f * 0.01)
	    	session[:cart] = response.merge(coupon: !session[:coupon].blank? ? session[:coupon] : "" , stripeCapturePercentage: ENV['stripeCapturePercentage'].to_f * 0.01)
	    	if @cart['carts'].present?
		    	@cartID = @cart['carts'][0]['cartID']
		    end
	    end
	  else
	  	
	  	@cartID = session[:cart_id].present? ? session[:cart_id] : session[:cart_id] = rand(0..1000) + rand(0..1000000)

	  	curlCall = `curl -H "appName: #{ENV['appName']}" -X GET #{SITEurl}/api/v1/carts?cartID=#{@cartID}`
	    response = Oj.load(curlCall)
	    
	    if response['success']
	    	@cart = response.merge(stripeCapturePercentage: ENV['stripeCapturePercentage'].to_f * 0.01)
	    	session[:cart] = response.merge(stripeCapturePercentage: ENV['stripeCapturePercentage'].to_f * 0.01)
	    end
	  end

	  @lineItems = []
	    	
  	@cart['carts'].each do |cartInfo|
			cartInfo['cart'].each do |item|
				@lineItems << {connectAccount: cartInfo['connectAccount'], price: item['stripePriceInfo']['id'], quantity: item['quantity'], shippable: item['stripeProductInfo']['shippable'], description: "#{item['stripeProductInfo']['name']} | #{item['stripePriceInfo']['metadata']['description']}"}
				@serviceFee = @cart['serviceFee']
			end
		end

		session[:lineItems] = @lineItems

	  @subtotal = !session[:coupon].blank? ? ((100 - session[:percentOff]) * 0.01) * @cart["subItemsTotal"]  : @cart["subItemsTotal"]
		@application_fee_amount = (@subtotal * (ENV['serviceFee'].to_i * 0.01)).to_i
		@stripeFee = (((@subtotal+@application_fee_amount) * 0.029) + 30).to_i
		@shippable = @lineItems.present? ? @lineItems.map{|itm| itm[:shippable]}.uniq.include?(true) : nil

		@jsonAmount = @subtotal + @application_fee_amount + @stripeFee
		
	end

	def stripeAmount(string)
    converted = (string.gsub(/[^0-9]/i, '').to_i)

    if string.include?(".")
      dollars = string.split(".")[0]
      cents = string.split(".")[1]

      if cents.length == 2
        stripe_amount = "#{dollars}#{cents}"
      else
        if cents === "0"
          stripe_amount = ("#{dollars}00")
        else
          stripe_amount = ("#{dollars}#{cents.to_i * 10}")
        end
      end

    else
      stripe_amount = converted * 100
    end
    return stripe_amount.to_i
  end

	private

	protected
	def configure_permitted_parameters
	  devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :email, :password, :password_confirmation]) 
  end
end
