#!/usr/bin/env ruby

require 'date'
require 'json'

if ARGV.size != 2
  $stderr.puts('usage: calc_emissions.rb [longharbor_nft|cursed_mikes] [acquire_logs.txt]')
end

COLLECTION_NAME = ARGV[0]
CURSED_MIKES_MINT = DateTime.parse('2022-01-27T17:00:00.000Z')
CURSED_WALLET = 'CursEdTaHUfDa7WevxE5UvF9TzTm4cSCihtdqQJ6EUun'

def emission_total(acquired_at)
  eligible_days = (DateTime.now - acquired_at).to_i
  case COLLECTION_NAME
  when 'cursed_mikes'
    # $CURSE drops in Feb. 2022 are 2x multiplied
    eligible_days * 2
  when 'longharbor_nft'
    days_before_cursed_mikes_mint = (CURSED_MIKES_MINT - acquired_at).to_i
    # Days until the Cursed Mike mint only count for 1 $CURSE.
    # $CURSE drops in Feb. 2022 are 2x multiplied = 5 daily emission instead of 2.5.
    days_before_cursed_mikes_mint + ((eligible_days - days_before_cursed_mikes_mint) * 5)
  else
     fail 'You must specify longharbor_nft or cursed_mikes to set the appropriate token daily emission'
  end
end

errors = []
token_account = "3hWBSqyHrJMDkSuAQtBYHwgKmMbJ666we5xegfDmMzGd"
results = File.read(ARGV[1]).lines.map(&:chomp).map { |line|
  begin
    j = JSON.parse(line)
    if j['timestamp']
      acquired_at = DateTime.parse(j['timestamp'])
    else
      errors << "No timestamp in line: #{line}"
      next
    end
    if j['transaction'] && j['transaction']['owner'] && !CURSED_WALLET.eql?(j['transaction']['owner'])
      owner = j['transaction']['owner']
    else
      errors << "No timestamp in line: #{line}" if !CURSED_WALLET.eql?(j['transaction']['owner'])
      next
    end
    # Deductions for being listing will be added subsequently.
    emission = emission_total(acquired_at)
    "spl-token transfer --fund-recipient --allow-unfunded-recipient #{token_account} #{emission} #{owner}"
  rescue e
    errors << e.to_s
  end
}.compact
File.puts('errors.txt', errors.join("\n")) unless errors.empty?
puts results
