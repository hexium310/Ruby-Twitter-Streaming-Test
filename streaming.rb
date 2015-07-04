# coding: utf-8

require 'twitter'
require 'yaml'
require 'oauth'
require 'time'

# 認証
def connect_twitter
  keys = YAML.load_file('./consumer.yml')
  puts '接続中...'
  @client = Twitter::Streaming::Client.new do |config|
    config.consumer_key        = keys['twitter']['consumer_key']
    config.consumer_secret     = keys['twitter']['consumer_secret']
    config.access_token        = @access_token
    config.access_token_secret = @access_token_secret
  end

  @rest_client = Twitter::REST::Client.new do |config|
    config.consumer_key        = keys['twitter']['consumer_key']
    config.consumer_secret     = keys['twitter']['consumer_secret']
    config.access_token        = @access_token
    config.access_token_secret = @access_token_secret
  end

  @user_name        = @rest_client.user.name
  @user_screen_name = @rest_client.user.screen_name
  puts '接続成功'
  puts "現在接続中のアカウントは(#{@user_screen_name})です。"
end

# ストリーム接続
def stream
  @statuses = {}
  @client.user do |status|
    case status
    when Twitter::Tweet
      @statuses["#{status.id}"] = status.to_h
      if @view_tl
        time = status.created_at.to_s
        time = Time.parse(time)
        puts "#{status.user.name} (#{status.user.screen_name})"
        puts status.text
        puts "#{time.strftime('%Y/%m/%d %H:%M:%S')} #{status.source.gsub(/(<a href=".*" rel=".*">)(.*)(<\/a>)/, '\2')}"
        puts '-------------------------------------'
      end
      unless @favorite_target == nil
        for value in @favorite_target
          @rest_client.favorite(status.id) if status.text.include?(value)
        end
      end
    when Twitter::Streaming::DeletedTweet
      if @delete_save
        next unless @statuses["#{status.id}"]
        name        = @statuses["#{status.id}"][:user][:name]
        screen_name = @statuses["#{status.id}"][:user][:screen_name]
        text        = @statuses["#{status.id}"][:text]
        time        = @statuses["#{status.id}"][:created_at]
        time        = Time.parse(time)
        source      = @statuses["#{status.id}"][:source]
        source      = source.gsub(/(<a href=".*" rel=".*">)(.*)(<\/a>)/, '\2')
        save_file(name, screen_name, text, time.strftime('%Y/%m/%d %H:%M:%S'), source)
      end
    end
  end
end

# 削除されたツイートのファイル保存
def save_file(name, screen_name, text, time, source)
  if File.exist?("./save_#{@user_screen_name}.txt")
    File.open("./save_#{@user_screen_name}.txt", 'a') do |file|
      file.puts("#{name} (@#{screen_name})")
      file.puts("#{text}")
      file.puts("#{time} #{source}")
      file.puts('')
    end
  else
    File.open("./save_#{@user_screen_name}.txt", 'w')
    save_file(name, screen_name, text, time, source)
  end
end

# コンフィグのロード
def load_config
  @register = false
  if File.exist?('./config.yml')
    if ARGV[0]
      yaml       = YAML.load_file('./config.yml')
      keys_array = []
      for values in yaml
        keys_array = keys_array + values.keys
      end
      if keys_array.include?(ARGV[0])
        n                    = keys_array.index(ARGV[0])
        @access_token        = yaml[n][ARGV[0]]['access_token']
        @access_token_secret = yaml[n][ARGV[0]]['access_token_secret']
        @favorite_target     = yaml[n][ARGV[0]]['favorite']
        @delete_save         = yaml[n][ARGV[0]]['delete_save']
        @view_tl             = yaml[n][ARGV[0]]['view_tl']
      else
        puts '指定されたユーザーの情報はありません。新しく登録してください。'
        register_account
        @register = true
      end
    else
      puts 'アカウントの情報を新しく登録します'
      register_account
      @register = true
    end
  else
    puts 'アカウントの情報を新しく登録します'
    register_account
    @register = true
  end
  connect_twitter
end

# コンフィグファイルの作成
def make_config
  keys = YAML.load_file('./consumer.yml')
  if File.exist?('./config.yml')
    yaml = YAML.load_file('./config.yml')
  else
    yaml = []
  end
  hash = [
    {
      @user_screen_name =>
      {
        'access_token'        => @access_token,
        'access_token_secret' => @access_token_secret,
        'favorite'            => nil,
        'delete_save'         => false,
        'view_tl'             => true
      }
    }
  ]
  hash = yaml + hash

  File.open('./config.yml', 'w') do |f|
    YAML.dump(hash, f)
  end
end

# アカウントの登録
def register_account
  keys  = YAML.load_file('./consumer.yml')
  oauth = OAuth::Consumer.new(
            keys['twitter']['consumer_key'],
            keys['twitter']['consumer_secret'],
            site: "https://api.twitter.com"
          )
  get_rt = oauth.get_request_token
  puts "#{get_rt.authorize_url}"
  puts '上記アドレスにアクセスして認証して出てきたPINを入力してください => '
  pin                  = (STDIN.gets.chomp).to_i
  get_at               = get_rt.get_access_token(oauth_verifier: pin)
  @access_token        = get_at.token
  @access_token_secret = get_at.secret
end

load_config
make_config if @register
stream
