require 'json'

MANAGE_CANISTER = "rrkah-fqaaa-aaaaa-aaaaq-cai"
GENESIS_TOKEN_CANISTER = "renrk-eyaaa-aaaaa-aaada-cai"
NNS_IFACES_DIR = File.expand_path(File.dirname(__FILE__), 'nns-ifaces-0.8.0')
OUT_FILE_PATH = File.expand_path(File.dirname(__FILE__), 'dman-out.txt')
OUT_FILE = File.new(OUT_FILE_PATH, 'w')

def parse_subexp(s, r)
  if s =~ r
    $1
  end
end

def parse_state(parsed_result)
  state = parse_subexp(parsed_result, /\sstate\s+=\s+(\d+)[^\d]/i)
  if state.nil?
    'Error'
  elsif state == '3'
    'Dissolved'
  elsif state == '2'
    'Dissolving'
  elsif state == '1'
    'Staking'
  end
end

def parse_number(parsed_result, field_name)
  r = parse_subexp(parsed_result, /\s#{field_name}\s+=\s+([\d_]+)[^\d]/i)
  if r
    r.to_i
  end
end

def parse_duration(parsed_result, field_name)
  r = parse_number(parsed_result, field_name)
  if r
    mm, ss = r.divmod(60)
    hh, mm = mm.divmod(60)
    dd, hh = hh.divmod(24)
    yy, dd = dd.divmod(365)
    r = ", %d years, %d days, %d hours, %d minutes, %d seconds" % [yy, dd, hh, mm, ss]
    r.gsub(/ 0 \w+,/, '').gsub(/\A, /, '')
  end
end

def parse_timestamp(parsed_result, field_name)
  r = parse_number(parsed_result, field_name)
  if r
    Time.at(r).to_s
  end
end

def print_neuron(id, parsed_result)
  <<-EOS
\tID: #{id}
\tState: #{parse_state(parsed_result)}
\tDissolve delay: #{parse_duration(parsed_result, 'dissolve_delay_seconds')}
\tAge: #{parse_duration(parsed_result, 'age_seconds')}
\tCreated at: #{parse_timestamp(parsed_result, 'created_timestamp_seconds')}
\tRetrieved at: #{parse_timestamp(parsed_result, 'retrieved_at_timestamp_seconds')}
\tVoting power: #{parse_number(parsed_result, 'voting_power')}
EOS
end

def output(string)
  OUT_FILE.write string
  print string
end

def outputln(string)
  output("#{string}\n")
end

def get_neuron_ids(legacy_address)
  result = %x{dfx canister --network=https://ic0.app --no-wallet call #{GENESIS_TOKEN_CANISTER} get_account '("#{legacy_address}")' --output=raw}.strip
  # quick and dirty parsing into JSON format
  parsed_result = %x{didc decode -t "(Result_2)" -d #{NNS_IFACES_DIR}/genesis_token.did "#{result}"}

  ids = JSON.parse(parsed_result.gsub(/record\s*\{\s*([^\s=]+)\s*=\s*(.+?)\s*:\snat64;\};/, '{ "\1": "\2" },').gsub(/\A.*neuron_ids\s*=\s*vec\s*\{/m, '[').gsub(/\},\};\n.+\z/m, '}]'))
  ids.map do |r|
    r['id'].strip
  end
end

unless Dir.exist?(NNS_IFACES_DIR)
  puts "Please copy the nns-ifaces-0.8.0 folder to #{NNS_IFACES_DIR}"
  puts "Exiting..."
  exit
end

if ARGV.size == 1
  if ARGV[0].size != 40
    puts "Error: Legacy Address should be 40 characters long, but was #{ARGV[0].size} characters"
    exit
  end
  legacy_address = ARGV[0]
  puts "Saving to #{OUT_FILE_PATH}..."
  output "Generated at: "
  outputln Time.now.to_s
  puts "Fetching Neuron IDs..."
  get_neuron_ids(legacy_address).each_with_index do |neuron_id, idx|
    result = %x{dfx canister --network=https://ic0.app --no-wallet call #{MANAGE_CANISTER} get_neuron_info "(#{neuron_id}:nat64)" --output=raw}.strip
    parsed_result = %x{didc decode -t "(Result_2)" -d #{NNS_IFACES_DIR}/governance.did "#{result}"}
    outputln "Neuron ##{idx}"
    output print_neuron(neuron_id, parsed_result)
  end
else
  puts "Usage: ruby dman.rb <LEGACY-ADDRESS>"
end

OUT_FILE.close
