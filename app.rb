# frozen_string_literal: true

require 'base64'
require 'bigdecimal'
require 'rack-timeout'
require 'logger'
require 'ostruct'
require 'reline'
require 'rack/null_logger'
require 'roda'
require 'forme'
require 'sass-embedded'
require 'zip'
require 'securerandom'
require 'json'
require 'fileutils'
require 'pry' unless ENV['RACK_ENV'] == 'production'

require_relative 'config/credentials'
require_relative 'lib/clamav_service'

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
class App < Roda # rubocop:disable Metrics/ClassLength
  # Ensure required directories exist at startup
  FileUtils.mkdir_p('tmp/stravaexport_done')

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

    r.on 'health' do
      r.is do
        health_status = {
          status: 'ok',
          timestamp: Time.now.iso8601,
          clamav: {
            enabled: ClamAVService.enabled?,
            available: ClamAVService.ping
          }
        }

        if ClamAVService.enabled? && !ClamAVService.ping
          response.status = 503
          health_status[:status] = 'degraded'
        end

        response['Content-Type'] = 'application/json'
        health_status.to_json
      end
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

        # Virus scan the uploaded file
        scan_result = ClamAVService.scan_file(export_file[:tempfile].path)

        unless scan_result[:success]
          response.status = 503
          return 'Upload temporarily unavailable'
        end

        unless scan_result[:clean]
          response.status = 400
          return "Security threat detected: #{scan_result[:message]}. Upload rejected."
        end

        random = SecureRandom.hex
        # Use sanitized directory name instead of user-provided filename to prevent path traversal
        safe_dir_name = "upload_#{strava_id}"
        temppath_base = "tmp/stravaexport_#{random}"
        temppath_of_export = "#{temppath_base}/#{safe_dir_name}"

        FileUtils.mkdir_p(temppath_of_export)

        # Use Ruby methods instead of shell commands for better security
        unless system('unzip', '-q', export_file[:tempfile].path, '-d', temppath_of_export)
          raise StandardError, 'Failed to unzip the uploaded file'
        end

        # Copy and execute the organizer with proper argument handling
        FileUtils.cp('strava-export-organizer', "#{temppath_of_export}/strava-export-organizer")
        Dir.chdir(temppath_of_export) { system('./strava-export-organizer', language) }

        input_directory = "#{temppath_of_export}/export_mapped" # directory to be zipped
        zipfile_name = "tmp/stravaexport_done/export_#{random[0..20]}_mapped.zip" # zip-file name
        FileUtils.rm_f(zipfile_name) # Remove if exists, using FileUtils instead of shell command

        # TODO: https://github.com/rubyzip/rubyzip/wiki/Updating-to-version-3.x#zipfile
        Zip::File.open(zipfile_name, create: true) do |zipfile|
          Dir.glob("#{input_directory}/**/*").select { |fn| legit_file?(fn) }.each do |file|
            zipfile.add(file.sub("#{input_directory}/", ''), file)
          end
        end

        # Skipping output file scan as input is already scanned and processing is safe.
      rescue StandardError => e
        p e
        response.status = 500
        return 'Error, the uploaded file is not a valid Strava export file'
      else
        response.status = 201
        r.redirect("/download?file=#{zipfile_name.split('/').last}")
        'Success'
      ensure
        FileUtils.rm_rf(temppath_base) if defined?(temppath_base) && temppath_base
        # Clean up old Rack multipart files
        system('find', '/tmp', '-name', 'RackMultipart.*', '-type', 'f', '-mmin', '+59', '-delete',
               out: File::NULL, err: File::NULL)
      end
    end
  end
end
