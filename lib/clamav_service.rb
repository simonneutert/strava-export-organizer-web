# frozen_string_literal: true

require 'clamav/client'
require 'logger'

# Service class for ClamAV virus scanning
class ClamAVService
  class << self
    def enabled?
      ENV['CLAMAV_ENABLED'] == 'true'
    end

    def scan_file(file_path) # rubocop:disable Metrics/MethodLength
      return success_result('ClamAV disabled - file not scanned') unless enabled?

      begin
        logger.info("ClamAV: Scanning file: #{file_path}")
        response = client.execute(ClamAV::Commands::ScanCommand.new(file_path)).first
        logger.info("ClamAV: Response class: #{response.class.name}")
        logger.info("ClamAV: Response virus_name: #{response.virus_name.inspect}")

        if response.virus_name
          logger.warn("ClamAV: Virus detected - #{response.virus_name}")
          infected_result(response.virus_name, file_path)
        else
          logger.info('ClamAV: File is clean')
          success_result('File is clean')
        end
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, SocketError => e
        logger.error("ClamAV: Connection error - #{e.message}")
        connection_error_result(e.message)
      rescue StandardError => e
        logger.error("ClamAV: Scan error - #{e.class.name}: #{e.message}")
        logger.error("ClamAV: Backtrace - #{e.backtrace.first(5).join("\n")}")
        error_result(e.message)
      end
    end

    def scan_stream(io_stream) # rubocop:disable Metrics/MethodLength
      return success_result('ClamAV disabled - stream not scanned') unless enabled?

      begin
        logger.info('ClamAV: Scanning stream')
        response = client.execute(ClamAV::Commands::InstreamCommand.new(io_stream))
        logger.info("ClamAV: Response class: #{response.class.name}")
        logger.info("ClamAV: Response virus_name: #{response.virus_name.inspect}")

        if response.virus_name
          logger.warn("ClamAV: Virus detected in stream - #{response.virus_name}")
          infected_result(response.virus_name, 'uploaded file')
        else
          logger.info('ClamAV: Stream is clean')
          success_result('Stream is clean')
        end
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, SocketError => e
        logger.error("ClamAV: Connection error - #{e.message}")
        connection_error_result(e.message)
      rescue StandardError => e
        logger.error("ClamAV: Scan error - #{e.class.name}: #{e.message}")
        logger.error("ClamAV: Backtrace - #{e.backtrace.first(5).join("\n")}")
        error_result(e.message)
      end
    end

    def ping
      return false unless enabled?

      begin
        logger.info('ClamAV: Pinging daemon')
        result = client.execute(ClamAV::Commands::PingCommand.new)
        logger.info("ClamAV: Ping result: #{result}")
        result
      rescue StandardError => e
        logger.error("ClamAV: Ping failed - #{e.message}")
        false
      end
    end

    private

    def logger
      @logger ||= Logger.new($stdout)
    end

    def client
      @client ||= begin
        logger.info("ClamAV: Initializing client - #{clamav_host}:#{clamav_port}")
        connection = ClamAV::Connection.new(
          socket: TCPSocket.new(clamav_host, clamav_port),
          wrapper: ClamAV::Wrappers::NewLineWrapper.new
        )
        ClamAV::Client.new(connection)
      end
    end

    def clamav_host
      ENV.fetch('CLAMAV_HOST', 'localhost')
    end

    def clamav_port
      ENV.fetch('CLAMAV_PORT', '3310').to_i
    end

    def success_result(message)
      {
        success: true,
        clean: true,
        message: message,
        virus_name: nil
      }
    end

    def infected_result(virus_name, file_info)
      {
        success: true,
        clean: false,
        message: "Virus detected: #{virus_name} in #{file_info}",
        virus_name: virus_name
      }
    end

    def connection_error_result(error_message)
      {
        success: false,
        clean: nil,
        message: "ClamAV connection error: #{error_message}",
        virus_name: nil
      }
    end

    def error_result(error_message)
      {
        success: false,
        clean: nil,
        message: "ClamAV scan error: #{error_message}",
        virus_name: nil
      }
    end
  end
end
