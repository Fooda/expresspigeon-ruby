require './lib/api'
require 'pigeon_helper'

describe 'contacts integration test' do

  include PigeonSpecHelper

  it 'should not create contact without contact data' do
    resp = PIGEON.contacts.upsert(-1, {})
    validate_response resp, 400, 'error', /contact and contact.email are required/
  end
  it 'should not create contact without email' do
    resp = PIGEON.contacts.upsert -1, :email => '', :first_name => 'Marylin', :last_name => 'Monroe'
    validate_response resp, 400, 'error', /contact and contact.email are required/
  end

  it 'should not add contact with too many custom fields' do
    custom_fields = {}
    (1..25).each { |n| custom_fields["custom_field_#{n}"] = n }
    resp = PIGEON.contacts.upsert -1,  :email => "mary@e.e", :custom_fields => custom_fields
    validate_response resp, 400, 'error', /You cannot create more than 20 custom fields. Use one of the 'custom_fields'./
  end

  it 'should not create new contact without list_id' do
    resp = PIGEON.contacts.upsert '', :email => 'ee@e.e', :first_name => 'Marylin', :last_name => 'Monroe'
    validate_response resp, 404, 'error', /contact=ee@e.e not found/
  end

  it 'test_create_with_suppressed_contact' do
    resp = PIGEON.contacts.upsert -1,  :email => 'suppressed@e.e'
    validate_response resp, 400, 'error', /contact=suppressed@e.e is in suppress list/
  end

  it 'cannot create with non-existent_list' do
    resp = PIGEON.contacts.upsert -1, :email => "e@e.e"
    validate_response resp, 404, 'error', /list=-1 not found/
  end

  it 'creates list with contacts' do
    list_response = PIGEON.lists.create 'My List', 'John Doe', 'john@doe.com'
    list_id = list_response.list.id
    resp = PIGEON.contacts.upsert list_id, email: "mary@e.e",
                                  :custom_fields => {:custom_field_1 => "custom_value_1", }
    validate_response resp, 200, 'success', /contact=mary@e.e created\/updated successfully/
    resp.contact.custom_fields.custom_field_1.should eq 'custom_value_1'
    resp.contact.email.should eq 'mary@e.e'
    resp.contact.email_format.should eq 'html'
    resp.contact.status.should eq 'ACTIVE'
    PIGEON.lists.delete(list_id)
  end

  it 'creates list non-existent custom field' do
    list_response = PIGEON.lists.create 'My List', 'John Doe', 'a@a.a'
    list_id = list_response.list.id
    resp = PIGEON.contacts.upsert(list_id, {:email => "mary@e.e", :custom_fields => {:c => "c", }})
    validate_response resp, 200, 'success', nil
    PIGEON.lists.delete(list_id)
  end

  it 'cannot export contacts from list without list_id' do
    content = ''
    PIGEON.lists.csv "-1" do |c|
      content << c
    end
    resp = JSON.parse(content)
    validate_response MetaHash.new(resp), 404, 'error', /list=-1 not found/
  end

  it 'should get contacts from suppressed list' do
    content =''
    PIGEON.lists.csv "suppress_list" do |c|
      content += c
    end
    resp = content.split /\n/
    resp.size.should eq 2
    resp[1].should =~ /"suppressed@e.e","Suppressed","Doe"/
  end

  it 'should get single contact' do
    resp = PIGEON.contacts.find_by_email 'suppressed@e.e'
    resp.email.should eq 'suppressed@e.e'
  end

  it 'should not find non existent contact' do
    resp = PIGEON.contacts.find_by_email 'a@a.a'
    validate_response resp, 404, 'error', /contact=a@a.a not found/
  end

  it 'should update contact' do

    list_response = PIGEON.lists.create('My List', 'John Doe', "a@a.a")
    resp = PIGEON.contacts.upsert list_response.list.id,
                                  :email => "mary@e.e", :first_name => "Mary", :last_name => "Doe"
    validate_response resp, 200, 'success', /contact=mary@e.e created\/updated successfully/
    PIGEON.contacts.find_by_email("mary@e.e").last_name.should eq 'Doe'

    resp = PIGEON.contacts.upsert list_response.list.id,
                                  :email => 'mary@e.e', :first_name => 'Mary', :last_name => 'Johns'
    validate_response resp, 200, 'success', /contact=mary@e.e created\/updated successfully/
    PIGEON.contacts.find_by_email("mary@e.e").last_name.should eq 'Johns'
  end

  it 'cannot delete contact with non-existent email' do
    res = PIGEON.contacts.delete("g@g.g")
    validate_response res, 404, 'error', /contact=g@g.g not found/
  end

  it 'should not delete suppressed contact' do
    res = PIGEON.contacts.delete("suppressed@e.e")
    validate_response res, 400, 'error', /contact=suppressed@e.e is in suppress list/
  end

  it 'should delete single contact from all lists' do
    list_response = PIGEON.lists.create 'My List', 'Jane Doe', 'a@a.a'
    PIGEON.contacts.upsert list_response.list.id, :email => 'mary@e.e'
    res = PIGEON.contacts.delete 'mary@e.e'
    validate_response res, 200, 'success', /contact=mary@e.e deleted successfully/
    PIGEON.lists.delete list_response.list.id
  end

  it 'deletes single contact from single list' do
    list_response = PIGEON.lists.create 'My List', 'John D.', 'a@a.a'
    list_response_2 = PIGEON.lists.create('My List2', "Jane D.", 'a@a.a')
    PIGEON.contacts.upsert(list_response.list.id, {:email => 'mary@e.e'})
    PIGEON.contacts.upsert(list_response_2.list.id, {:email => 'mary@e.e'})

    res = PIGEON.contacts.delete 'mary@e.e', list_response.list.id

    validate_response res, 200, 'success', /contact=mary@e.e deleted successfully/

    contacts_exported = ''
    PIGEON.lists.csv list_response.list.id do |c|
      contacts_exported << c
    end
    contacts_exported = contacts_exported.split /\n/
    contacts_exported.size.should eq 1

    contacts_exported_2 = ''
    PIGEON.lists.csv list_response_2.list.id do |c|
      contacts_exported_2 << c
    end

    contacts_exported_2 = contacts_exported_2.split /\n/
    contacts_exported_2.size.should eq 2
    contacts_exported_2[1].should =~ /"mary@e.e"/

    PIGEON.lists.delete(list_response.list.id)
    PIGEON.lists.delete(list_response_2.list.id)
    PIGEON.contacts.delete('mary@e.e')
  end
end

