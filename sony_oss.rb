# -*- coding: utf-8 -*-
require 'uri'
require 'open-uri'
require 'nokogiri'

def scan_product url
  puts url
end

def scan_category url
  puts url
  charset = nil
  html = open(url) do |f|
    charset = f.charset # 文字種別を取得
    f.read # htmlを読み込んで変数htmlに渡す
  end
  doc = Nokogiri::HTML.parse(html, nil, charset)
  doc.xpath('//table[@class="w480"]').each do |node|
    node.css('tr').each do |tr|
      category = tr.xpath('./th[@class="category"]').inner_text
      puts category
      tr.css('a').each do |a|
        scan_product URI.join(url, a.attribute('href').value)
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
