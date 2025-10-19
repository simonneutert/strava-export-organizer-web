# frozen_string_literal: true

require 'clamav/client'

# Service class for ClamAV virus scanning
class ClamAVService
  class << self
    def enabled?
      ENV['CLAMAV_ENABLED'] == 'true'
    end

    def scan_file(file_path) # rubocop:disable Metrics/MethodLength
      return success_result('ClamAV disabled - file not scanned') unless enabled?

      begin
        response = client.execute(ClamAV::Commands::ScanCommand.new(file_path)).first

        if response.is_a?(ClamAV::VirusResponse)
          infected_result(response.virus_name, file_path)
        elsif response.is_a?(ClamAV::SuccessResponse)
          success_result('File is clean')
        else
          error_result('Unknown response type')
        end
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, SocketError => e
        connection_error_result(e.message)
      rescue StandardError => e
        error_result(e.message)
      end
    end

    def scan_stream(io_stream) # rubocop:disable Metrics/MethodLength
      return success_result('ClamAV disabled - stream not scanned') unless enabled?

      begin
        response = client.execute(ClamAV::Commands::InstreamCommand.new(io_stream))

        if response.is_a?(ClamAV::VirusResponse)
          infected_result(response.virus_name, 'uploaded file')
        elsif response.is_a?(ClamAV::SuccessResponse)
          success_result('Stream is clean')
        else
          error_result('Unknown response type')
        end
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, SocketError => e
        connection_error_result(e.message)
      rescue StandardError => e
        error_result(e.message)
      end
    end

    def ping
      return false unless enabled?

      begin
        client.execute(ClamAV::Commands::PingCommand.new)
      rescue StandardError
        false
      end
    end

    private

    def client
      @client ||= begin
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
