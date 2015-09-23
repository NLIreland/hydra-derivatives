require 'mini_magick'

module Hydra
  module Derivatives
    class Image < Processor
      class_attribute :timeout

      def process
        timeout ? process_with_timeout : process_without_timeout
      end

      def process_with_timeout
        status = Timeout::timeout(timeout) do
          process_without_timeout
        end
      rescue Timeout::Error => ex
        raise Hydra::Derivatives::TimeoutError, "Unable to process image derivative\nThe command took longer than #{timeout} seconds to execute"
      end

      def process_without_timeout
        directives.each do |name, args|
          opts = args.kind_of?(Hash) ? args : {size: args}
          format = opts.fetch(:format, 'png')
          quality = opts.fetch(:quality, nil)
          destination_name = output_filename_for(name, opts)
          create_resized_image(destination_name, opts[:size], format, quality)
        end
      end

      def output_filename_for(name, opts = {})
        if opts.has_key? :datastream
          Deprecation.warn Hydra::Derivatives::Image, 'The :datastream option is deprecated and will be removed in hydra-derivatives 3.0.0.'
        end
        opts.fetch(:datastream, output_file_id(name))
      end

      protected

      def new_mime_type(format)
        MIME::Types.type_for(format).first.to_s
      end

      def create_resized_image(destination_name, size, format, quality=nil)
        create_image(destination_name, format, quality) do |xfrm|
          xfrm.resize(size) if size.present?
        end
      end

      def create_image(destination_name, format, quality=nil)
        xfrm = load_image_transformer
        yield(xfrm) if block_given?
        xfrm.format(format)
        xfrm.quality(quality.to_s) if quality
        write_image(destination_name, format, xfrm)
      end

      def write_image(destination_name, format, xfrm)
        output_io = Hydra::Derivatives::IoDecorator.new(StringIO.new)
        output_io.mime_type = new_mime_type(format)

        xfrm.write(output_io)
        output_io.rewind

        output_file_service.call(object, output_io, destination_name)
      end

      # Override this method if you want a different transformer, or need to load the
      # raw image from a different source (e.g.  external file)
      def load_image_transformer
        MiniMagick::Image.read(source_file.content)
      end
    end
  end
end
