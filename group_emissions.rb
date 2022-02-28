#!/usr/bin/env ruby

require 'date'
require 'json'

if ARGV.size != 4
  $stderr.puts('usage: calc_emissions.rb [longharbor_nft|cursed_mikes] [./2022-02-11/9QyeH5pmnNEWqnHzNtoeDFn8QVwVgvdvuNKu6TfHiJgg_holders.json] [./2022-02-11/last-transactions.json] [./2022-02-18/last-transactions.json]')
end

COLLECTION_NAME = ARGV[0]
snapshot = JSON.parse(File.read(ARGV[1]))
CURSED_WALLET = 'CursEdTaHUfDa7WevxE5UvF9TzTm4cSCihtdqQJ6EUun'

def emission_total(eligible_days)
  case COLLECTION_NAME
  when 'cursed_mikes'
    # $CURSE drops in Feb. 2022 are 2x multiplied
    eligible_days * 2
  when 'longharbor_nft'
    # Days until the Cursed Mike mint only count for 1 $CURSE.
    # $CURSE drops in Feb. 2022 are 2x multiplied = 5 daily emission instead of 2.5.
    eligible_days * 5
  else
     fail 'You must specify longharbor_nft or cursed_mikes to set the appropriate token daily emission'
  end
end

errors = []
token_account = "3hWBSqyHrJMDkSuAQtBYHwgKmMbJ666we5xegfDmMzGd"
previous_transactions = File.read(ARGV[2]).lines.map(&:chomp).map { |line| JSON.parse(line) }.reduce(:merge)
current_transactions = File.read(ARGV[3]).lines.map(&:chomp).map { |line| JSON.parse(line) }.reduce(:merge)
emissions = {}
results = snapshot.map { |mint|
  #require 'pry'; binding.pry
  begin
    # Deductions for being listing will be added subsequently.
    previous_tx = previous_transactions[mint['mint_account']]
    current_tx = current_transactions[mint['mint_account']]
    emission = emission_total(7)
    #"spl-token transfer --fund-recipient --allow-unfunded-recipient #{token_account} #{emission} #{owner}"
    #emissions[mint['owner_wallet']] ||= []
    JSON.generate({
      timestamp: current_tx['timestamp'],
      via: "unmoved",
      emission: emission,
      mint: mint['mint_account'],
      token_account: token_account,
      owner: mint['owner_wallet'],
    }) if previous_tx['signature'].eql?(current_tx['signature'])
  rescue => e
    errors << JSON.generate({ message: e.to_s, stacktrace: e.backtrace })
    nil
  end
}.compact
File.write('errors.txt', errors.join("\n")) unless errors.empty?
puts results 
