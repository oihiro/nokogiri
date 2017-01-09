# -*- coding: utf-8 -*-
#
# pana_oss.rb
#
# scrape the Panasonic OSS site
#

require 'uri'
require 'open-uri'
require 'nokogiri'
require 'optparse'
require 'pg'

#
# カテゴリ、モデル、OSSを全て記録するクラス
#
class ProductOSS
  attr_accessor :last_ctg

  def initialize
    @h = {}
    @tv_h = {}
  end

  def set_ctg name
    @last_ctg = name
    if (name == 'TV') then
      @tv_h[name] = {}
      @tv_h[name]
    else
      @h[name] = {}
      @h[name]
    end
  end

  def set_area name, _h
    if (!_h[name]) then 
      _h[name] = {}
    end
    _h[name]
  end

  def set_year name, _h
    if (!_h[name]) then 
      _h[name] = {}
    end
    _h[name]
  end

  def set_osses_to_models _models, _osses, _h
    _models.each do |m|
      _h[m] = {}
      _osses.each do |o|
        _h[m][o] = true
      end
    end
  end
  
  def print_all
    @tv_h.keys.sort.each do |c|
      @tv_h[c].keys.sort.each do |a|
        @tv_h[c][a].keys.sort.each do |y|
          @tv_h[c][a][y].keys.sort.each do |m|
            @tv_h[c][a][y][m].keys.each do |o|
              puts "#{c}|#{a}|#{y}|#{m}|#{o['oss']}|#{o['package']}|#{o['ossurl']}"
            end
          end
        end
      end
    end

    @h.keys.sort.each do |c|
      @h[c].keys.sort.each do |m|
        @h[c][m].keys.each do |o|
          puts "#{c}|||#{m}|#{o['oss']}|#{o['package']}|#{o['ossurl']}"
        end
      end
    end
  end

  def create_tbl connection, tblname
    connection.exec(<<-"EOS")
      CREATE TABLE #{tblname} (
        category VARCHAR(80),
        area VARCHAR(80),
        year VARCHAR(80),
        model VARCHAR(80),
        oss VARCHAR(256),
        package VARCHAR(256),
        ossurl VARCHAR(256)
      );
    EOS
  end

  def insert_tbl connection, tbl
    i = 1
    @tv_h.keys.sort.each do |c|
      @tv_h[c].keys.sort.each do |a|
        @tv_h[c][a].keys.sort.each do |y|
          @tv_h[c][a][y].keys.sort.each do |m|
            @tv_h[c][a][y][m].keys.each do |o|
              begin
                connection.exec(<<-EOS)
                  INSERT INTO #{tbl} (category, area, year, model, oss, package, ossurl)
                  VALUES(\'#{c}\', \'#{a}\', \'#{y}\', \'#{m}\', \'#{o['oss'].gsub(/'/, "''")}\', \'#{o['package']}\', \'#{o['ossurl']}\');
                EOS
                # o['oss']にはシングルクォーテーションが入る場合があり、そのときはシングルクォーテーション２つへのエスケープ処理が必要になる
              rescue => e
                p e
                puts "#{c}|#{a}|#{y}|#{m}|#{o['oss']}|#{o['package']}|#{o['ossurl']}"
                raise e
              end
              if (i % 1000 == 0) then
                now "insert #{i}"
              end
              i = i + 1
            end
          end
        end
      end
    end
    @h.keys.sort.each do |c|
      @h[c].keys.sort.each do |m|
        @h[c][m].keys.each do |o|
          begin
            connection.exec(<<-EOS)
            INSERT INTO #{tbl} (category, model, oss, package, ossurl)
            VALUES(\'#{c}\', \'#{m}\', \'#{o['oss']}\', \'#{o['package']}\', \'#{o['ossurl']}\');
            EOS
          rescue => e
            p e
            puts "#{c}|||#{m}|#{o['oss']}|#{o['package']}|#{o['ossurl']}"
              raise e
          end
          if (i % 1000 == 0) then
            now "insert #{i}"
          end
          i = i + 1
        end
      end
    end
  end
end

def dbgputs str
  if ($OPTS[:debug]) then
    STDERR.puts str
  end
end

#
# 各モデルのページをスキャンする
#
def scan_model url, models, _h
  dbgputs "scan_model: url=#{url}"
  charset = nil
  a = []

  html = open(url) do |f|
    charset = f.charset # 文字種別を取得
    f.read # htmlを読み込んで変数htmlに渡す
  end
  doc = Nokogiri::HTML.parse(html, nil, charset)
  doc.xpath('//table[2]').each do |node|
    node.css('a').each do |anode|
      h = {}
      oss = anode.inner_text.strip
      ossurl = anode.attribute('href').value
      package = ossurl.sub(/^(.*\/)(.*)$/) {$2}
      if !(oss.include? 'Copyright') then
        h['oss'] = oss
        h['ossurl'] = ossurl
        h['package'] = package
        a.push h
      end
    end
  end
  $product_oss.set_osses_to_models models, a, _h
  a
end

#
# 各年のページをスキャンする
#
def scan_year url, _h
  dbgputs "scan_year: url=#{url}"
  charset = nil
  h = {}

  html = open(url) do |f|
    charset = f.charset # 文字種別を取得
    f.read # htmlを読み込んで変数htmlに渡す
  end
  doc = Nokogiri::HTML.parse(html, nil, charset)
  doc.xpath('//table[2]').each do |node|
    node.css('a').each do |anode|
      models = anode.inner_text.split(/\s*\/\s*/)
      uri = URI.join(url, anode.attribute('href').value)
      unless h[uri] then # 既にジャンプしたページならば飛ばない
        # 製品モデルのページにジャンプしてスキャン
        h[uri] = scan_model uri, models, _h # ossesを返す
      else
        $product_oss.set_osses_to_models models, h[uri], _h
      end
    end
  end
end

#
# 各エリアのページをスキャンする
#
def scan_area url, _h
  dbgputs "scan_area: url=#{url}"
  charset = nil

  html = open(url) do |f|
    charset = f.charset # 文字種別を取得
    f.read # htmlを読み込んで変数htmlに渡す
  end
  doc = Nokogiri::HTML.parse(html, nil, charset)
  doc.xpath('//table[2]').each do |node|
    node.css('a').each do |anode|
      _hh = $product_oss.set_year anode.inner_text, _h
      scan_year URI.join(url, anode.attribute('href').value), _hh
    end
  end
end

#
# 各カテゴリのページをスキャンする
#
def scan_category url, _h
  dbgputs "scan_category: url=#{url}"
  charset = nil
  h = {}

  html = open(url) do |f|
    charset = f.charset # 文字種別を取得
    f.read # htmlを読み込んで変数htmlに渡す
  end
  doc = Nokogiri::HTML.parse(html, nil, charset)
  doc.xpath('//table[2]').each do |node|
    node.css('a').each do |anode|
      if $product_oss.last_ctg == 'TV'
        _hh = $product_oss.set_area anode.inner_text, _h
        scan_area URI.join(url, anode.attribute('href').value), _hh
      else
        models = anode.inner_text.split(/\s*\/\s*/)
        uri = URI.join(url, anode.attribute('href').value)
        unless h[uri] then # 既にジャンプしたページならば飛ばない
          # 製品モデルのページにジャンプしてスキャン
          h[uri] = scan_model uri, models, _h # ossesを返す
        else
          $product_oss.set_osses_to_models models, h[uri], _h
        end
      end
    end
  end
end

def now msg
  STDERR.puts "#{msg}:#{Time.now}"
end
public :now

#
# main routine begin
#
now "start."

# スクレイピング先のURL
# トップカテゴリのリストが並ぶページ
url = 'http://panasonic.net/avc/oss/'

$OPTS = {}
opt = OptionParser.new
opt.on('--debug') {|v| $OPTS[:debug] = v}
opt.on('--print') {|v| $OPTS[:print] = v}
opt.on('--db') {|v| $OPTS[:db] = v}
opt.on('--createtbl=TBL') {|v| $OPTS[:createtbl] = v}
opt.parse!(ARGV)

$product_oss = ProductOSS.new

charset = nil
html = open(url) do |f|
  charset = f.charset # 文字種別を取得
  f.read # htmlを読み込んで変数htmlに渡す
end

# p html

# htmlをパース(解析)してオブジェクトを作成
doc = Nokogiri::HTML.parse(html, nil, charset)

# 2個目のTABLE
doc.xpath('//table[2]').each do |node|
  # link
  node.css('a').each do |anode|
    h = $product_oss.set_ctg anode.inner_text
    # 各トップカテゴリのページに飛んでスキャン
    scan_category URI.join(url, anode.attribute('href').value), h
  end
end

now "site parsing finished."

if ($OPTS[:print]) then
  $product_oss.print_all
end

if ($OPTS[:db]) then
  # connect to the PostgreSQL DB.
  # User, Password, Databaseはデフォルト設定
  now "connecting to the DB."
  connection = PG::connect(:host => "localhost")

  begin
    if ($OPTS[:createtbl]) then
      connection.exec("drop table if exists #{$OPTS[:createtbl]};")
      $product_oss.create_tbl connection, $OPTS[:createtbl]
      $product_oss.insert_tbl connection, $OPTS[:createtbl]
    end
  ensure
    connection.finish
  end
end


