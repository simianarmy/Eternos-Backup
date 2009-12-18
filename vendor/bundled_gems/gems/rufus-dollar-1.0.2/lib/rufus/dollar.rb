#
#--
# Copyright (c) 2006-2009, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#++
#

#
# "made in Japan"
#
# John Mettraux at openwfe.org
#


module Rufus

  #
  # Performs 'dollar substitution' on a piece of text with a given
  # dictionary.
  #
  #   require 'rubygems'
  #   require 'rufus/dollar'
  #
  #   h = {
  #     "name" => "Fred Brooke",
  #     "title" => "Silver Bullet"
  #   }
  #
  #   puts Rufus::dsub "${name} wrote '${title}'", h
  #     # => "Fred Brooke wrote 'Silver Bullet'"
  #
  def self.dsub (text, dict, offset=nil)

    text = text.to_s

    j = text.index('}', offset || 0)

    return text unless j

    t = text[0, j]

    i = t.rindex('${')
    ii = t.rindex("\\${")

    iii = t.rindex('{')
    iii = nil if offset

    return text unless i
    return dsub(text, dict, j+1) if (iii) and (iii-1 > i)

    return unescape(text) if (i) and (i != 0) and (ii == i-1)
      #
      # found "\${"

    key = text[i+2..j-1]

    value = dict[key]

    value = if value
      value.to_s
    else
      dict.has_key?(key) ? 'false' : ''
    end

    pre = (i > 0) ? text[0..i-1] : ''

    dsub("#{pre}#{value}#{text[j+1..-1]}", dict)
  end

  private

  def self.unescape (text)

    text.gsub("\\\\\\$\\{", "\\${")
  end

end

