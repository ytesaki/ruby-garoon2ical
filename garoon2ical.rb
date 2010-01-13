#!/usr/bin/env ruby
require 'rubygems'
require 'mechanize'
require 'csv'
require 'icalendar'
require 'kconv'
require 'yaml'

$KCODE = 'u'

#設定の読み込み
conf = YAML.load_file("config.yaml")

agent = WWW::Mechanize.new
page = agent.get conf["cybozu_url"]
form = page.forms.first
form.field_with(:name => "_account").value = conf["username"]
form.field_with(:name => "_password").value = conf["password"]
result = form.submit

#ここまでで、ログインできてる
form =result.forms.first

#現在日付から 90日とってみよう
today = Date.today
endday = today + conf["date_range"]

form.field_with(:name => "start_year").value = today.year
form.field_with(:name => "start_month").value = today.month
form.field_with(:name => "start_day").value = "1"
form.field_with(:name => "end_year").value = endday.year
form.field_with(:name => "end_month").value = endday.month
form.field_with(:name => "end_day").value = endday.day
form.field_with(:name => "charset").value = "UTF-8"
form.radiobutton_with(:name => "item_name",:value => "0").check
result2 = form.submit

#open(conf["calname"]+".csv","w") do |f|
#  f.print result2.body
#end

csv = CSV.parse(result2.body.toutf8)
# iCalオブジェクトの生成
cal = Icalendar::Calendar.new
csv.each do |sc|
  cal.event do
    dtstart       DateTime.parse(sc[0]+" "+sc[1]), {'TZID' => 'Asia/Tokyo'}
    dtend         DateTime.parse(sc[2]+" "+sc[3]), {'TZID' => 'Asia/Tokyo'}
    summary     sc[5]+"("+sc[4]+")"
    description     sc[6].sub(/\n/,"")
  end
end
# STANDARD コンポーネントを生成
standard_component = Icalendar::Component.new('STANDARD')
standard_component.custom_property('dtstart', '19700101T000000')
standard_component.custom_property('tzoffsetfrom', '+0900')
standard_component.custom_property('tzoffsetto', '+0900')
standard_component.custom_property('tzname', 'JST')

# VTIMEZONE コンポーネントを生成
vtimezone_component = Icalendar::Component.new('VTIMEZONE')
vtimezone_component.custom_property('tzid', 'Asia/Tokyo')
vtimezone_component.add(standard_component)
cal.add(vtimezone_component)

# iCalファイル生成
File.open(conf["calname"]+".ics", "w+b") { |f|
    f.write(cal.to_ical.toutf8)
}
