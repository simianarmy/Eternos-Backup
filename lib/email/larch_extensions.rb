# $Id$

require 'larch'

# Extend Larch::IMAP::Mailbox with search capabilities

module Larch
  def self.format_date_for_search(date)
    date.strftime("%d-%b-%Y")
  end
  
  class IMAP
    # Represents an IMAP mailbox.
    class Mailbox
      # searches mailbox for all emails (or after a certain date)
      def fetch_ids(opts={})
        ids = []
        if opts[:since]
          results = imap_search(['SINCE', opts[:since]])
          if results.any? 
            @last_id = results.first - 1
            # current mailbox is used in scan method
            scan
            ids = @ids.keys
          end
        else
          each {|id| ids << id}
        end
        ids
      end

      private
      # Fetches the specified _fields_ for the specified _set_ of UIDs (either a
      # Range or an Array of UIDs).
      def imap_search(fields)
        @imap.safely do
          imap_select
          @imap.conn.search(fields)
        end
      end
    end
  end
end
