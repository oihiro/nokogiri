# -*- coding: utf-8 -*-
#
# sony_oss.rb
#
# scrape the SONY OSS site
#

require 'uri'
require 'open-uri'
require 'nokogiri'

#
# product_category.hash["Digital TV"][0].model[0]
#                                  .oss[0]
#
class ProductCategory
  class ModelOss
    attr_accessor :model, :oss

    def initialize
      @oss = Array.new
    end
  end

  def new_category_array name
    @hash[name] = Array.new
  end

  def push_category_array name
    unless @hash[name] then
      new_category_array name
    end
    @hash[name].push ModelOss.new
    @hash[name].last
  end

  def initialize
    @hash = Hash.new
  end

  def get_hash
    @hash
  end
end

def print_product_category
  oss_global_h = {}
  @product_category.get_hash.each do |k, v|
    model_num = 0
    oss_num = 0
    model_h = {}
    oss_h = {}
    v.each do |e|
      model_num = model_num + e.model.size
      oss_num = oss_num + e.oss.size
      e.model.each do |m|
        model_h[m] = 1
      end
      e.oss.each do |o|
        oss_h[o] = 1
        oss_global_h[o] = 1
      end
    end
    puts "category=\"#{k}\" model_num=#{model_num} oss_num=#{oss_num} model_unique=#{model_h.keys.size} oss_unique=#{oss_h.keys.size}"
  end
  puts "whole oss_unique=#{oss_global_h.keys.size}"
  open("sony_oss_list.txt", "w") do |f|
    oss_global_h.keys.sort.each do |k|
      f.puts "#{k}"
    end
  end
end

def scan_oss a_oss, url
  #puts "scan_oss: url=#{url}"
  charset = nil
  i = 0

  html = open(url) do |f|
    charset = f.charset
    f.read
  end
  doc = Nokogiri::HTML.parse(html, nil, charset)
  doc.xpath('//table[@class="w90"]').each do |node|
    node.css('li').each do |li|
      a_oss.push li.inner_text.strip
    end
  end
end

#
# scan Products/Linux/XXX/Category0X.html
#
def scan_product url
  #puts "scan_product: url=#{url}"
  charset = nil
  i = 0

  html = open(url) do |f|
    charset = f.charset
    f.read
  end
  doc = Nokogiri::HTML.parse(html, nil, charset)
  doc.xpath('//table[@class="w100 bgC"]').each do |node|
    node.css('tr').each do |tr|
      if i == 0 then # first tr -> skip because title
        i = 1
        next
      end
      td = tr.css('td')
      name = td[0].inner_text # category name
      unless @product_category then
        @product_category = ProductCategory.new
      end
      ar = @product_category.push_category_array name
      ar.model = td[1].inner_text.gsub(/[\s"]/, "").split(/[,\/]/) # model list
      #puts "ar.model = #{ar.model}"
      scan_oss ar.oss, URI.join(url, tr.css('a')[0].attribute('href').value)
      #puts "ar.oss = #{ar.oss}"
    end
  end
end

def scan_category url
  #puts "scan_category: url=#{url}"
  charset = nil
  h = {}

  html = open(url) do |f|
    charset = f.charset # 文字種別を取得
    f.read # htmlを読み込んで変数htmlに渡す
  end
  doc = Nokogiri::HTML.parse(html, nil, charset)
  doc.xpath('//table[@class="w480"]').each do |node|
    node.css('tr').each do |tr|
      category = tr.xpath('./th[@class="category"]').inner_text
      if category && category.length > 0 then # 1個目のtrがcategory。2個目のtrがURLを指定。
        puts "category=#{category}"
      else
        tr.css('a').each do |a|
          uri = URI.join(url, a.attribute('href').value)
          unless h[uri] then
            h[uri] = true
            scan_product uri
          end
        end
      end
    end
  end
end

# スクレイピング先のURL
url = 'http://oss.sony.net/Products/Linux/common/search.html'

charset = nil
html = open(url) do |f|
  charset = f.charset # 文字種別を取得
  f.read # htmlを読み込んで変数htmlに渡す
end

# p html

# htmlをパース(解析)してオブジェクトを作成
doc = Nokogiri::HTML.parse(html, nil, charset)

doc.xpath('//table[@class="w480"]').each do |node|
  # link
  node.css('a').each do |anode|
    scan_category URI.join(url, anode.attribute('href').value)
  end
end

print_product_category
