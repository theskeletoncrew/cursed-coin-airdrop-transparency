#!/usr/bin/env ruby

require 'date'
require 'json'

if ARGV.size != 3
  $stderr.puts('usage: calc_emissions.rb [longharbor_nft|cursed_mikes] [9QyeH5pmnNEWqnHzNtoeDFn8QVwVgvdvuNKu6TfHiJgg_holders.json] [acquire_logs.txt]')
end

AIRDROP_DATE = DateTime.parse('2022-02-11T17:00:00:00.000Z')
COLLECTION_NAME = ARGV[0]
snapshot = JSON.parse(File.read(ARGV[1]))
CURSED_MIKES_MINT = DateTime.parse('2022-01-27T17:00:00.000Z')
CURSED_WALLET = 'CursEdTaHUfDa7WevxE5UvF9TzTm4cSCihtdqQJ6EUun'
MAGIC_EDEN_V2_ADDRESS = 'M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K'
EXCHANGE_ART_ADDRESS = 'AmK5g2XcyptVLCFESBCJqoSfwV3znGoVYQnqEnaAZKWn'

def emission_total(acquired_at)
  eligible_days = (AIRDROP_DATE - acquired_at).to_i
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
results = File.read(ARGV[2]).lines.map(&:chomp).map { |line|
  begin
    j = JSON.parse(line)
    s = snapshot.find { |s| s['mint_account'].eql?(j['mint']) }
    fail "Mint address #{j['mint'].to_json} was not found in snapshot." if s.nil?
    tx = j['transactions'].index { |tx|
      tx['instructions'].any? { |i| ('spl-associated-token-account'.eql?(i['programName']) \
                                && 'create-associated-token-account'.eql?(i['parsed_type'])) \
                                || ('spl-token'.eql?(i['programName']) \
                                    && 'initialize-token-account'.eql?(i['parsed_type']))
      }
    } || j['transactions'].size - 1
    acquired_at = DateTime.parse(j['transactions'][tx]['timestamp'])
    if j['transactions']
      owner = s['owner_wallet']
    else
      errors << "Missing transaction in line: #{line}"
      next
    end
    # Deductions for being listing will be added subsequently.
    emission = emission_total(acquired_at)
    #"spl-token transfer --fund-recipient --allow-unfunded-recipient #{token_account} #{emission} #{owner}"
    JSON.generate({
      via: "post-mint-transfer",
      emission: emission,
      mint: j['mint'],
      token_account: token_account,
      owner: owner,
    })
  rescue => e
    errors << e.to_s
    nil
  end
}.compact
File.write('errors.txt', errors.join("\n")) unless errors.empty?
puts results
