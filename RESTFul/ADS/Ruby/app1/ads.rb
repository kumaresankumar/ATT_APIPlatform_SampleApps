#!/usr/bin/env ruby

# Copyright 2014 AT&T
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'sinatra'
require 'open-uri'
require 'sinatra/config_file'

# require as a gem file load relative if fails
begin
  require 'att/codekit'
rescue LoadError
  # try relative, fall back to ruby 1.8 method if fails
  begin
    require_relative 'codekit/lib/att/codekit'
  rescue NoMethodError 
    require File.join(File.dirname(__FILE__), 'codekit/lib/att/codekit')
  end
end
  

#simplify our namespace
include Att::Codekit

enable :sessions

config_file 'config.yml'

set :port, settings.port
set :protection, :except => :frame_options

SCOPE = 'ADS'

#Setup proxy used by att/codekit
Transport.proxy(settings.proxy)

configure do
  begin
    VALID_PARAMS = [:MMA]
    OAuth = Auth::ClientCred.new(settings.FQDN,
                                 settings.api_key,
                                 settings.secret_key)
    @@token = nil
  rescue Exception => e
    @error = e.message
  end
end

# Setup filter for token handling
[ '/getAds' ].each do |action|
  before action do
    begin
      if @@token.nil?
        @@token = OAuth.createToken(SCOPE)
      end
      if @@token && @@token.expired?
        @@token = OAuth.refreshToken(@@token) 
      end
    rescue Exception => e
      @error = e.message
    end
  end
end

get '/' do
  erb :ads
end

post '/getAds' do
  begin
    service = Service::ADSService.new(settings.FQDN, @@token)

    optional = Hash.new

    VALID_PARAMS.each do |p|
      optional[p] = params[p].strip unless params[p].nil? or params[p].strip.empty?
    end

    category = params[:Category]
    user_agent = @env["HTTP_USER_AGENT"].to_s
    udid = "012266005922565000000000000000"

    @ad = service.getAds(category, user_agent, udid, optional) 

  rescue Exception => e
    @error = e.message
  end
  erb :ads
end

