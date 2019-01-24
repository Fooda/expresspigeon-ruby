
require_relative '../lib/expresspigeon-ruby.rb'

MESSAGES = ExpressPigeon::API.messages.auth_key(ENV['AUTH_KEY'])

#attachments = %W{attachments/attachment1.txt  attachments/smile.pdf attachments/example.ics}
#attachments = %W{/home/igor/tmp/The-Definitive-Guide-To-Mobile-Marketing-Marketo.pdf}
attachments = %W{/home/igor/tmp/Express-Pigeon-PropertyRadar-MSA-12-13-15.pdf}

puts MESSAGES.send_message(
    390243,                                     # template_id
    'igor@polevoy.org',                         #to
    'igor@polevoy.org',                         #reply_to
    "Igor Polevoy",                             #from_name
    "Hi there! Attachments and header",         #subject
    {first_name: 'Igor', eye_color: 'blue'},    #merge_fields
    false,                                      #view_online
    true,                                       #click_tracking
    true,                                       #suppress_address
    attachments,                                 #file paths to upload as attachments
    {Sender: 'Vasya Pupkin <vasya@polevoy.org>'}
)
