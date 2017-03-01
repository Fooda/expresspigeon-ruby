require './lib/expresspigeon-ruby'
require 'pigeon_helper'

describe 'campaigns integration test' do

  include PigeonSpecHelper

  it 'should return more than 0 campaign ids' do
    res = ExpressPigeon::API.campaigns.all
    res.class.should == Array
    res.size.should > 0
  end

  it 'cannot send with missing parameters' do
    res = ExpressPigeon::API.campaigns.send(:template_id => 15233, :name => 'API Test campaign',
                                          :from_name => 'Igor Polevoy', :reply_to => 'igor@polevoy.org',
                                          :subject => 'API test', :google_analytics => true)
    validate_response res, 400, 'error', /required parameters: list_id, template_id, name, from_name, reply_to, subject, google_analytics/
  end

  it 'cannot send with bad reply_to' do
    res = ExpressPigeon::API.campaigns.send(:list_id => -1, :template_id => -1, :name => 'My Campaign', :from_name => 'John', :reply_to => 'j',
                                          :subject => 'Hi', :google_analytics => false)
    validate_response res, 400, 'error', /reply_to should be valid email address/
  end

  it 'cannot send with non-existing template' do
    res = ExpressPigeon::API.campaigns.send(:list_id => -1, :template_id => -1, :name => 'My Campaign', :from_name => 'John',
                                          :reply_to => 'j@j.j',
                                          :subject => 'Hi', :google_analytics => false)
    validate_response res, 400, 'error', /template=-1 is not found/
  end

  it 'cannot send to non-existing list' do
    res = ExpressPigeon::API.campaigns.send(:list_id => -1, :template_id => TEMPLATE_ID, :name => 'My Campaign', :from_name => 'John',
                                          :reply_to => 'j@j.j',
                                          :subject => 'Hi', :google_analytics => false)
    validate_response res, 400, 'error', /list=-1 is not found/
  end

  it 'cannot send to disabled list' do
    res = ExpressPigeon::API.campaigns.send(:list_id => LIST_ID, :template_id => TEMPLATE_ID, :name => 'My Campaign', :from_name => 'John',
                                          :reply_to => 'j@j.j',
                                          :subject => 'Hi', :google_analytics => false)
    validate_response res, 400, 'error', /list=#{DISABLED_LIST} is disabled/
  end

  it 'should create new list, add contact and send successful campaign' do

    list_resp = ExpressPigeon::API.lists.create('My list', 'John', API_USER)
    list_id = list_resp.list.id
    ExpressPigeon::API.contacts.upsert(list_id, {:email => API_USER})
    resp = ExpressPigeon::API.campaigns.send(:list_id => list_id, :template_id => TEMPLATE_ID, :name => 'My Campaign', :from_name => 'John',
                                           :reply_to => API_USER,
                                           :subject => 'Hi', :google_analytics => false)
    validate_response resp, 200, 'success', /new campaign created successfully/
    report = ExpressPigeon::API.campaigns.report(resp.campaign_id)
    (report.delivered == 0 or report.delivered == 1).should be_true
    report.clicked.should eq 0
    report.opened.should eq 0
    report.spam.should eq 0
    (report.in_transit == 0 or report.in_transit == 1).should be_true
    report.unsubscribed.should eq 0
    report.bounced.should eq 0
    bounced = ExpressPigeon::API.campaigns.bounced(resp.campaign_id)
    unsubscribed = ExpressPigeon::API.campaigns.unsubscribed(resp.campaign_id)
    spam = ExpressPigeon::API.campaigns.spam(resp.campaign_id)

    bounced.size.should eq 0
    unsubscribed.size.should eq 0
    spam.size.should eq 0

    resp = ExpressPigeon::API.contacts.delete(API_USER)
    validate_response resp, 200, 'success', /contact=non@non.non deleted successfully/

    resp = ExpressPigeon::API.contacts.find_by_email(API_USER)
    validate_response resp, 404, 'error', /contact=non@non.non not found/

    resp = ExpressPigeon::API.lists.delete(list_id)
    validate_response resp, 200, 'success', /deleted successfully/
  end


  it 'cannot send campaign if scheduling with bad date' do

    list_resp = ExpressPigeon::API.lists.create "My list", "John", API_USER
    resp = ExpressPigeon::API.campaigns.schedule :list_id => list_resp.list.id, :template_id => TEMPLATE_ID, :name => 'My Campaign',

                                               :from_name => 'John',
                                               :reply_to => API_USER, :subject => 'Hi',
                                               :google_analytics => false, :schedule_for => "2013-05-28"

    validate_response resp, 400, 'error', /schedule_for is not in ISO date format, example: 2013-05-28T17:19:50.779/
    resp = ExpressPigeon::API.lists.delete(list_resp.list.id)
    validate_response resp, 200, 'success', /deleted successfully/
  end

  it 'should not schedule campaign with date in the past' do
    list_resp = ExpressPigeon::API.lists.create('My list', 'John', API_USER)
    resp = ExpressPigeon::API.campaigns.schedule :list_id => list_resp.list.id, :template_id => TEMPLATE_ID, :name => 'My Campaign',
                                               :from_name => 'John',
                                               :reply_to => API_USER, :subject => 'Hi',
                                               :google_analytics => false, :schedule_for => '2010-05-28T17:19:50.779+0300'

    validate_response resp, 400, 'error', /schedule_for should be in the future/
  end



  it 'should delete scheduled campaign' do
    list_resp = ExpressPigeon::API.lists.create('My list', 'John', API_USER)
    resp = ExpressPigeon::API.campaigns.schedule :list_id => list_resp.list.id, :template_id => TEMPLATE_ID, :name => 'My Campaign',
                                               :from_name => 'John',
                                               :reply_to => API_USER, :subject => 'Hi',
                                               :google_analytics => false, :schedule_for => '2030-05-28T17:19:50.779+0300'

    validate_response resp, 200, 'success', /new campaign created successfully/
    campaign_id = resp.campaign_id
    resp = ExpressPigeon::API.campaigns.delete campaign_id
    resp.message.should eq "campaign #{campaign_id} was deleted"
  end


  # This test uses account ep.api.tester@expresspigeon.com and expects two specific campaign there.
  it 'should list campaigns from account' do
    campaigns = ExpressPigeon::API.campaigns.all
    campaigns.size.should eq 4
    campaigns = ExpressPigeon::API.campaigns.all from_id: 53853
    campaigns.size.should eq 3
  end


  it 'should get opened from campaign' do
    opened = ExpressPigeon::API.campaigns.opened 441663

    puts opened

  end

  it 'should get clicked from campaign' do
    clicked = ExpressPigeon::API.campaigns.clicked 441663

    puts clicked

  end

  it 'should get unsubs from campaign' do
    unsubscribed = ExpressPigeon::API.campaigns.unsubscribed 441663

    puts unsubscribed

  end

end

