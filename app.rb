# frozen_string_literal: true

require 'base64'
require 'bigdecimal'
require 'rack-timeout'
require 'logger'
require 'reline'
require 'rack/null_logger'
require 'roda'
require 'forme'
require 'zip'
require 'securerandom'
require 'pry' unless ENV['RACK_ENV'] == 'production'

require_relative 'config/credentials'

CURRENT_DIR = File.dirname(__FILE__)

def legit_file?(filename)
  !skip_file?(filename)
end

def skip_file?(filename)
  File.directory?(filename) ||
    File.symlink?(filename) ||
    File.executable?(filename) ||
    !File.file?(filename)
end

class FileNotFoundError < StandardError
end

# Main application class
class App < Roda
  use Rack::Timeout, service_timeout: 600,
                     wait_timeout: false,
                     wait_overtime: false,
                     term_on_timeout: 1

  plugin :environments
  plugin :public
  plugin :route_csrf, check_header: true
  plugin :sessions, secret: 'some_nice_long_random_stringsome_nice_long_random_stringsome_nice_long_random_string'
  plugin :common_logger, Logger.new('log.log'), method: :debug

  plugin :error_handler do |e|
    if e.is_a?(FileNotFoundError)
      'Oh No! File not found! ☠️'
    else
      'Oh No! ☠️'
    end
  end

  plugin :render
  plugin :partials
  plugin :all_verbs
  plugin :sinatra_helpers
  plugin :indifferent_params
  plugin :forme_route_csrf
  plugin :assets, css: ['bulma.css', 'app.scss'],
                  js: ['vendor/htmx.js', 'app.js']
  compile_assets if ENV['RACK_ENV'] == 'production'

  plugin :i18n, locale: %w[en de]

  plugin :not_found do
    view('404')
  end

  route do |r| # rubocop:disable Metrics/BlockLength
    r.public # serve static assets
    r.assets # serve dynamic assets
    r.i18n_set_locale_from(:http)

    check_csrf!

    @file_lifespan = 5
    `find tmp/stravaexport_done/* -mmin +#{@file_lifespan} -exec rm {} ';'`

    r.root do
      r.redirect '/upload', 301
    end

    r.on 'faq' do
      view 'faq', layout: 'layout_faq'
    end

    r.on 'download' do
      zipfile_name = "tmp/stravaexport_done/#{r.params['file']}"

      r.on 'get' do
        raise FileNotFoundError, 'File not found' unless File.exist?("tmp/stravaexport_done/#{r.params['file']}")

        send_file zipfile_name, type: 'application/zip', filename: zipfile_name
      end

      r.is do
        view 'download', locals: { zipfile_url: "download/get/?file=#{r.params['file']}" }
      end
    end

    r.is 'upload' do # rubocop:disable Metrics/BlockLength
      @show_advertisement = true
      @show_cta = true
      r.get do
        view 'direct_upload'
      end

      r.post do # rubocop:disable Metrics/BlockLength
        language = r.params['language'] || 'de'
        export_file = r.params['stravaexportzip']
        strava_id = export_file[:filename].scan(/\d+/).first || (SecureRandom.rand * 10**8).to_i
        raise ArgumentError, 'Invalid Strava ID' if strava_id.nil? || strava_id.empty? || strava_id.length > 14

        random = SecureRandom.hex
        temppath_of_export = "tmp/stravaexport_#{random}/#{export_file[:filename].gsub('.zip', '')}"
        `mkdir tmp/stravaexport_#{random}`
        `mkdir tmp/stravaexport_#{random}/#{export_file[:filename].gsub('.zip', '')}`
        `unzip #{export_file[:tempfile].path} -d #{temppath_of_export}`
        `cp strava-export-organizer #{temppath_of_export}/strava-export-organizer`
        `cd #{temppath_of_export} && ./strava-export-organizer #{language}`

        FileUtils.mkdir_p('tmp/stravaexport_done') unless File.directory?('tmp/stravaexport_done')
        input_directory = "#{temppath_of_export}/export_mapped" # directory to be zipped
        zipfile_name = "tmp/stravaexport_done/export_#{random[0..20]}_mapped.zip" # zip-file name
        `rm #{zipfile_name}` || true # if file exists, delete it
        Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
          Dir.glob("#{input_directory}/**/*").select { |fn| legit_file?(fn) }.each do |file|
            zipfile.add(file.sub("#{input_directory}/", ''), file)
          end
        end
      rescue StandardError => e
        p e
        response.status = 500
        return 'Error, the uploaded file is not a valid Strava export file'
      else
        response.status = 201
        r.redirect("/download?file=#{zipfile_name.split('/').last}")
        'Success'
      ensure
        `rm -rf tmp/stravaexport_#{random}`
        `find /tmp -name 'RackMultipart.*' -type f -mmin +59 -delete > /dev/null`
      end
    end
  end
end
