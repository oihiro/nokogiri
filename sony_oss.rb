# -*- coding: utf-8 -*-
#
# sony_oss.rb
#
# scrape the SONY OSS site
#

require 'uri'
require 'open-uri'
require 'nokogiri'
require 'optparse'
require 'pg'

#
# 製品カテゴリとOSSを計数するために最初に作成したシンプルなクラス
#
# product_category.hash["Digital TV"][0].model[0]
#                                  .oss[0]
#
class ProductCategory

  # modelはString配列。プログラム中でString配列がセットされる。
  # ossもString配列。
  # 従って、1 modelにつき、複数のossを対応づけているわけではない。
  class ModelOss
    attr_accessor :model, :oss

    def initialize
      @oss = Array.new
    end
  end

  def new_category_array name
    @hash[name] = Array.new
  end

  # name = 製品カテゴリ
  # nameはhashのキー。そのhashの値にはModelOssの配列が入る。
  # 本メソッドは、呼ばれるとModelOssオブジェクトが新規作成され、配列にpushされる。値を格納するオブジェクトを予め生成することになる。
  # 既にキーとして存在しているnameに対して本メソッドが呼ばれたときはModelOssの配列は作成されず、単にModelOssオブジェクトが新規作成されるだけなので、その製品カテゴリに追加されることになる。
  # 戻り値：新規作成されたModelOssオブジェクト
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

#
# 3レイヤを全て記録するクラス
#
class ThreeLayerCategory
  def initialize
    @h = {}
  end

  def set_top_ctg name
    if (!@h[name]) then
      @h[name] = {}
    end
    @last_top = name
  end

  def set_snd_ctg name
    if (!@h[@last_top][name]) then 
      @h[@last_top][name] = {}
    end
    @last_snd = name
  end

  def set_thd_ctg name
    if (!@h[@last_top][@last_snd][name]) then
      @h[@last_top][@last_snd][name] = {}
    end
    @last_thd = name
  end

  def set_models _models
    _models.each do |e|
      @h[@last_top][@last_snd][@last_thd][e] = {}
    end
    @last_models = _models
  end

  def set_osses _osses
    @last_models.each do |m|
      @h[@last_top][@last_snd][@last_thd][m] = {}
      _osses.each do |o|
        @h[@last_top][@last_snd][@last_thd][m][o] = true
      end
    end
  end
  
  def print_all
    @h.keys.sort.each do |f|
      @h[f].keys.sort.each do |s|
        @h[f][s].keys.sort.each do |t|
          @h[f][s][t].keys.sort.each do |m|
            @h[f][s][t][m].keys.sort.each do |o|
              puts "#{f},#{s},#{t},#{m},#{o}"
            end
          end
        end
      end
    end
  end

  def create_tbl connection, tblname
    connection.exec(<<-"EOS")
      CREATE TABLE #{tblname} (
        top_ctg VARCHAR(80),
        snd_ctg VARCHAR(80),
        thd_ctg VARCHAR(80),
        model VARCHAR(80),
        oss VARCHAR(256)
      );
    EOS
  end

  def insert_tbl connection, tbl
    i = 1
    @h.keys.sort.each do |f|
      @h[f].keys.sort.each do |s|
        @h[f][s].keys.sort.each do |t|
          @h[f][s][t].keys.sort.each do |m|
            @h[f][s][t][m].keys.sort.each do |o|
              begin
                connection.exec(<<-EOS)
                  INSERT INTO #{tbl} (top_ctg, snd_ctg, thd_ctg, model, oss)
                  VALUES(\'#{f}\', \'#{s}\', \'#{t}\', \'#{m}\', \'#{o}\');
                EOS
              rescue => e
                p e
                puts "#{f},#{s},#{t},#{m},#{o}"
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
  end

end

def dbgputs str
  if ($OPTS[:debug]) then
    puts str
  end
end

def print_product_category
  oss_global_h = {}
  oss_global_num = 0
  # cvs output
  if ($OPTS[:category]) then
    puts "\"product category\",model,unique model,oss,unique oss"
  end
  $product_category.get_hash.each do |k, v|
    model_num = 0
    oss_num = 0
    model_h = {}
    oss_h = {}
    v.each do |e|
      model_num = model_num + e.model.size
      oss_num = oss_num + e.oss.size
      oss_global_num = oss_global_num + e.oss.size
      e.model.each do |m|
        model_h[m] = 1
      end
      e.oss.each do |o|
        oss_h[o] = 1
        oss_global_h[o] = 1
      end
    end
    # ruby command line
    #puts "product category=\"#{k}\" model_num=#{model_num} oss_num=#{oss_num} model_unique=#{model_h.keys.size} oss_unique=#{oss_h.keys.size}"

    # csv output
    if ($OPTS[:category]) then
      puts "\"#{k}\",#{model_num},#{model_h.keys.size},#{oss_num},#{oss_h.keys.size}"
    end
    #
  end

  if ($OPTS[:total]) then
    puts "whole oss_num=#{oss_global_num}"
    puts "whole oss_unique=#{oss_global_h.keys.size}"
  end

  if (!$OPTS[:osslist].to_s.empty?) then
    open($OPTS[:osslist], "w") do |f|
      oss_global_h.keys.sort.each do |k|
        f.puts "#{k}"
      end
    end
  end
end

#
# 製品モデル毎のOSSのページをスキャン
#
def scan_oss a_oss, url
  dbgputs "scan_oss: url=#{url}"
  charset = nil
  i = 0

  html = open(url) do |f|
    charset = f.charset
    f.read
  end
  doc = Nokogiri::HTML.parse(html, nil, charset)
  doc.xpath('//table[@class="w90"]').each do |node|
    node.css('li').each do |li|
      anode = li.css('a')
      if (!anode[0].inner_text.include?("\n")) then
        a_oss.push anode[0].inner_text.strip
      end
    end
  end
end

#
# scan Products/Linux/XXX/Category0X.html
# 製品カテゴリ(category - model/module)のページをスキャン
# ここで製品カテゴリと呼んでいるのは、第三レベルカテゴリである。
#
def scan_product url
  dbgputs "scan_product: url=#{url}"
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
      name = td[0].inner_text.gsub(/"/,"") # get product category name
      #dbgputs "name = #{name}"
      unless $product_category then
        $product_category = ProductCategory.new
      end
      if (!name.to_s.empty?) then # !(nil or empty)  nil.to_s -> "" 空欄の行がある誤りへの対策
        ar = $product_category.push_category_array name
        # モデル名を得る最初の方式
        ar.model = td[1].inner_text.gsub(/[\s"]/, "").split(/[,\/]/) # model list
        # 第二の方式
        # 完璧ではない。相反するモデル記述があり、もっと正確に行おうとすると複雑化する
=begin
        inner_text = td[1].inner_text
        dbgputs "model_full = #{inner_text}"
        inner_text.gsub!(/\s*\([^\)]*\)\s*/) { |matched|
          matched.gsub(/\//, "&slash;").gsub(/\s/, "&space;")
        }
        if (/,/ =~ inner_text) then
          ar.model = inner_text.split(/\s*,\s*/)
        elsif (/\// =~ inner_text) then
          ar.model = inner_text.split(/\s*\/\s*/)
        elsif (/\s/ =~ inner_text) then
          ar.model = inner_text.split(/\s+/)
        else
          ar.model = []
          ar.model[0] = inner_text
        end
        ar.model.each_index do |i|
          if (ar.model[i]) then
            ar.model[i].gsub!(/&slash;/, "/")
            ar.model[i].gsub!(/&space;/, " ")
          end
        end
=end
        dbgputs "ar.model = #{ar.model}"
        # 製品モデル毎のOSSのページにジャンプしてスキャン
        if (!ar.model.empty?) then
          $threelayercategory.set_thd_ctg name
          $threelayercategory.set_models ar.model
          scan_oss ar.oss, URI.join(url, tr.css('a')[0].attribute('href').value)
          dbgputs "ar.oss = #{ar.oss}"
          $threelayercategory.set_osses ar.oss
        end
      end
    end
  end
end

#
# 第二、第三カテゴリのページをスキャンする
#
def scan_category url
  dbgputs "scan_category: url=#{url}"
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
      if category && category.length > 0 then # 1個目のtrが第二カテゴリ。2個目のtrがurlを指定。
        dbgputs "category=#{category}"
        $threelayercategory.set_snd_ctg category
      else
        tr.css('a').each do |a|
          uri = URI.join(url, a.attribute('href').value)
          # ここで第三カテゴリを示す文字列は取得しない。ジャンプ先で取得できるので。
          unless h[uri] then
            h[uri] = true # 既にジャンプしたページならば飛ばない
            # 製品カテゴリ（第三カテゴリ）のページにジャンプしてスキャン
            scan_product uri
          end
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
url = 'http://oss.sony.net/Products/Linux/common/search.html'

$OPTS = {}
opt = OptionParser.new
opt.on('--total') {|v| $OPTS[:total] = v}
opt.on('--category') {|v| $OPTS[:category] = v}
opt.on('--osslist=file') {|v| $OPTS[:osslist] = v}
opt.on('--debug') {|v| $OPTS[:debug] = v}
opt.on('--tlctg_print') {|v| $OPTS[:tlctg_print] = v}
opt.on('--tlctg_db') {|v| $OPTS[:tlctg_db] = v}
opt.on('--tlctg_createtbl=TBL') {|v| $OPTS[:tlctg_createtbl] = v}
opt.parse!(ARGV)

$threelayercategory = ThreeLayerCategory.new

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
    $threelayercategory.set_top_ctg anode.inner_text
    # 各トップカテゴリのページに飛んでスキャン
    scan_category URI.join(url, anode.attribute('href').value)
  end
end

now "site parsing finished."

print_product_category

if ($OPTS[:tlctg_print]) then
  $threelayercategory.print_all
end

if ($OPTS[:tlctg_db]) then
  # connect to the PostgreSQL DB.
  # User, Password, Databaseはデフォルト設定
  now "connecting to the DB."
  connection = PG::connect(:host => "localhost")

  begin
    if ($OPTS[:tlctg_createtbl]) then
      connection.exec("drop table if exists #{$OPTS[:tlctg_createtbl]};")
      $threelayercategory.create_tbl connection, $OPTS[:tlctg_createtbl]
      $threelayercategory.insert_tbl connection, $OPTS[:tlctg_createtbl]
    end
  ensure
    connection.finish
  end
end


