require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # First, make sure you have everything setup correctly and all of your dependencies in place with:
    #
    #   require 'rubygems'
    #   require 'active_merchant'
    #
    # ActiveMerchant expects the amounts to be given as an Integer in cents. In this case, $10 US becomes 1000.
    #
    #   tendollar = 1000
    #
    # The transaction result is based on the cent value of the transaction.
    #
    # Setup options, month and year must be the expiry date of the credit card used in the previous transaction
    # options = {
    #   :month => 6
    #   :year => 2014
    # }
    #
    #
    # To finish setting up, create the active_merchant object you will be using, with the eWay gateway. If you have a
    # functional eWay account, replace :login with your Customer ID and :password with XML Refund Password.
    #
    #   gateway = ActiveMerchant::Billing::Base.gateway(:eway_refund).new(:login => '87654321', :password => '******')
    #
    # Now we are ready to process our transaction, reference is the eway transaction number
    #
    #   response = gateway.refund(tendollar, reference, options)
    #
    # Sending a transaction to eWay with active_merchant returns a Response object, which consistently allows you to:
    #
    # 1) Check whether the transaction was successful
    #
    #   response.success?
    #
    # 2) Retrieve any message returned by eWay, either a "transaction was successful" note or an explanation of why the
    # transaction was rejected.
    #
    #   response.message
    #
    # This should be enough to get you started with eWay Refund and active_merchant. For further information, review the methods
    # below and the rest of active_merchant's documentation.

    class EwayRefundGateway < Gateway
      self.test_url = 'https://www.eway.com.au/gateway/xmltest/refund_test.asp'
      self.live_url = 'https://www.eway.com.au/gateway/xmlpaymentrefund.asp'

      self.money_format = :cents
      self.supported_countries = ['AU']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]
      self.homepage_url = 'http://www.eway.com.au/'
      self.display_name = 'eWAY'

      def initialize(options = {})
        requires!(options, :login)
        requires!(options, :password)
        super
      end

      # ewayCustomerEmail, ewayCustomerAddress, ewayCustomerPostcode
      def refund(money, reference, options = {})

        post = {}
        post[:OriginalTrxnNumber] = reference

        add_expiry(post, options)

        add_ref(post, options)

        add_other(post)

        commit(money, post)
      end

      private

      def add_expiry(post, options)
        requires!(options, :month)
        requires!(options, :year)
        post[:CardExpiryMonth]  = sprintf("%.2i", options[:month])
        post[:CardExpiryYear] = sprintf("%.2i", options[:year])[-2..-1]
      end

      def add_ref(post, options)
        post[:CustomerInvoiceRef] = options[:order_id]
      end

      def add_other(post)
        post[:Option1] = nil
        post[:Option2] = nil
        post[:Option3] = nil
      end

      def commit(money, parameters)
        parameters[:TotalAmount] = amount(money)

        response = parse( ssl_post(gateway_url(test?), post_data(parameters)) )

        Response.new(success?(response), message_from(response[:ewaytrxnerror]), response,
          :authorization => response[:ewayauthcode]
        )
      end

      def success?(response)
        response[:ewaytrxnstatus] == "True"
      end

      # Parse eway response xml into a convinient hash
      def parse(xml)
        #  "<?xml version=\"1.0\"?>".
        #  <ewayResponse>
        #    <ewayTrxnError></ewayTrxnError>
        #    <ewayTrxnStatus>True</ewayTrxnStatus>
        #    <ewayTrxnNumber>10002</ewayTrxnNumber>
        #    <ewayTrxnOption1></ewayTrxnOption1>
        #    <ewayTrxnOption2></ewayTrxnOption2>
        #    <ewayTrxnOption3></ewayTrxnOption3>
        #    <ewayReturnAmount>10</ewayReturnAmount>
        #    <ewayAuthCode>123456</ewayAuthCode>
        #    <ewayTrxnReference>987654321</ewayTrxnReference>
        #    </ewayResponse>
        #  <ewayResponse>

        response = {}
        xml = REXML::Document.new(xml)
        xml.elements.each('//ewayResponse/*') do |node|

          response[node.name.downcase.to_sym] = normalize(node.text)

        end unless xml.root.nil?

        response
      end

      def post_data(parameters = {})
        parameters[:CustomerID] = @options[:login]
        parameters[:RefundPassword] = @options[:password]


        xml   = REXML::Document.new
        root  = xml.add_element("ewaygateway")

        parameters.each do |key, value|
          root.add_element("eway#{key}").text = value
        end
        xml.to_s
      end

      def message_from(message)
        message
      end

      # Make a ruby type out of the response string
      def normalize(field)
        case field
        when "true"   then true
        when "false"  then false
        when ""       then nil
        when "null"   then nil
        else field
        end
      end

      def gateway_url(test)
        test ? self.test_url : self.live_url
      end

    end
  end
end
