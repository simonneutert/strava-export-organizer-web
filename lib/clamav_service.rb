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
        client_instance = client
        response = client_instance.execute(ClamAV::Commands::ScanCommand.new(file_path))

        if response.virus_name
          infected_result(response.virus_name, file_path)
        else
          success_result('File is clean')
        end
      rescue ClamAV::ConnectionError => e
        connection_error_result(e.message)
      rescue StandardError => e
        error_result(e.message)
      end
    end

    def scan_stream(io_stream) # rubocop:disable Metrics/MethodLength
      return success_result('ClamAV disabled - stream not scanned') unless enabled?

      begin
        client_instance = client
        response = client_instance.execute(ClamAV::Commands::InstreamCommand.new(io_stream))

        if response.virus_name
          infected_result(response.virus_name, 'uploaded file')
        else
          success_result('Stream is clean')
        end
      rescue ClamAV::ConnectionError => e
        connection_error_result(e.message)
      rescue StandardError => e
        error_result(e.message)
      end
    end

    def ping
      return false unless enabled?

      begin
        client_instance = client
        response = client_instance.execute(ClamAV::Commands::PingCommand.new)
        response.success?
      rescue StandardError
        false
      end
    end

    private

    def client
      Thread.current[:clamav_client] ||= ClamAV::Client.new(
        socket: ClamAV::Connection.new(
          socket: TCPSocket.new(clamav_host, clamav_port)
        ),
        wrapper: false
      )
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
