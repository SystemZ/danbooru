# frozen_string_literal: true

# @see Source::URL::Plurk
module Sources
  module Strategies
    class Plurk < Base
      def match?
        Source::URL::Plurk === parsed_url
      end

      def image_urls
        # * Posts can have up to 10 images.
        # * Artists commonly post extra images by replying to their own post.
        # * Adult posts are hidden for logged out users. The main images can be found by
        #   scraping a <script> tag, but an API call is needed to get the images in the replies.
        #
        # Examples:
        # * https://www.plurk.com/p/om6zv4 (non-adult, single image)
        # * https://www.plurk.com/p/okxzae (non-adult, multiple images, with replies)
        # * https://www.plurk.com/p/omc64y (adult, multiple images, with replies)

        if parsed_url.image_url?
          [url]
        elsif page_json["porn"]
          # in case of adult posts, we get the main images and the replies separately
          images_from_script_tag + images_from_replies
        else
          images_from_page
        end
      end

      def page_url
        return nil if illust_id.blank?
        "https://plurk.com/p/#{illust_id}"
      end

      def illust_id
        parsed_url.work_id || parsed_referer&.work_id
      end

      def page
        return nil if page_url.blank?

        response = http.cache(1.minute).get(page_url)
        return nil unless response.status == 200

        response.parse
      end

      # For non-adult works, returns both the main images and the images posted by the artist in the replies.
      # For adult works, returns only the main images.
      def images_from_page
        page&.search(".bigplurk .content a img, .response.highlight_owner .content a img").to_a.pluck("alt")
      end

      # Returns only the main images, not the images posted in the replies. Used for adult works.
      def images_from_script_tag
        URI.extract(page_json["content_raw"])
      end

      # Returns images posted by the artist in the replies. Used for adult works.
      def images_from_replies
        artist_responses = api_replies["responses"].to_a.select { _1["user_id"].to_i == artist_id.to_i }
        urls = artist_responses.pluck("content_raw").flat_map { URI.extract(_1) }
        urls.select { Source::URL.parse(_1)&.image_url? }.uniq
      end

      def page_json
        script_text = page&.search("body script").to_a.map(&:text).grep(/plurk =/).first.to_s
        json = script_text.strip.delete_prefix("plurk = ").delete_suffix(";").gsub(/new Date\((.*?)\)/) { $1 }
        return {} if json.blank?
        JSON.parse(json)
      end

      def api_replies
        return {} if illust_id.blank?

        response = http.cache(1.minute).post("https://www.plurk.com/Responses/get", form: { plurk_id: illust_id.to_i(36), from_response_id: 0 })
        return {} unless response.status == 200

        response.parse
      end

      def tag_name
        page&.at(".bigplurk .user a")&.[](:href)&.gsub(%r{^/}, "")
      end

      def artist_name
        page&.at(".bigplurk .user a")&.text
      end

      def artist_id
        page&.at("a[data-uid]")&.attr("data-uid").to_i
      end

      def profile_url
        return nil if artist_name.blank?
        "https://www.plurk.com/#{tag_name}"
      end

      def artist_commentary_desc
        page&.search(".bigplurk .content .text_holder, .response.highlight_owner .content .text_holder")&.to_html
      end

      def dtext_artist_commentary_desc
        DText.from_html(artist_commentary_desc) do |element|
          if element.name == "a"
            element.content = ""
          end
        end.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
      end

      def normalize_for_source
        page_url
      end

      memoize :page, :page_json, :api_replies
    end
  end
end
