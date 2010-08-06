#!/usr/bin/env ruby
require 'rubygems'
require 'bundler'
Bundler.setup
require 'sinatra'
require 'typhoeus'

class Rack::Proxy

  UNSAFE_HEADERS = ["Transfer-Encoding"]

#  ALL_HEADERS = ["X-Reader-User",
#                    "X-Frame-Options",
#                    "Transfer-Encoding",
#                    "X-Reader-Google-Version",
#                    "X-XSS-Protection",
#                    "Date",
#                    "Content-Type",
#                    "Server",
#                    "X-Content-Type-Options",
#                    "Cache-Control",
#                    "Expires"]

  def initialize(app)
    @app = app
    @hydra = Typhoeus::Hydra.new
  end

  def call(env)
    req = Rack::Request.new(env)
    # We need to use it twice, so read in the stream. This is an obvious problem with large bodies, so beware.
    req_body = req.body.read if req.body

    url = "https://www.google.com:443#{req.fullpath}"
    opts = {:timeout => 15000}
    opts.merge!(:method => req.request_method.downcase.to_sym)
    opts.merge!(:headers => {"Authorization" => env["HTTP_AUTHORIZATION"]}) if env["HTTP_AUTHORIZATION"]
    opts.merge!(:body => req_body) if req_body && req_body.length > 0

    request = Typhoeus::Request.new(url, opts)
    result_response = {}
    request.on_complete do |response|
      result_response[:code] = response.code
      result_response[:headers] = response.headers_hash
      result_response[:body] = response.body
    end
    @hydra.queue request

    # Concurrently executes both HTTP requests, blocks until they both finish
    @hydra.run

    #Typhoeus can add nil headers, lets get rid of them

    result_response[:headers].delete_if { |k, v| v == nil || UNSAFE_HEADERS.include?(k) }
    [result_response[:code], result_response[:headers], result_response[:body]]
  end
end

use Rack::Proxy