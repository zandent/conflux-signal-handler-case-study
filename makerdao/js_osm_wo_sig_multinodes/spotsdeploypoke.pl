#!/usr/bin/perl
use strict;
use warnings;
use POSIX;
use Time::HiRes qw( time );

my $num_nodes = int($ARGV[0]);
my $osm_addr = $ARGV[1];
my $total_time;
system("rm -rf deployreceipt.txt");

open( my $osm_fh,    ">", "osmpoke.js" ) or die $!;
my $message = <<"END_MESSAGE";
const { Conflux } = require('js-conflux-sdk');

const PRIVATE_KEY_OSM = '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

async function main() {
  const cfx = new Conflux({
    url: 'http://localhost:12539',
    defaultGasPrice: 1,
    defaultGas: 1000000,
    logger: console,
  });

  console.log(cfx.defaultGasPrice); // 100
  console.log(cfx.defaultGas); // 1000000

  // ================================ Account =================================
  const accountosm = cfx.Account(PRIVATE_KEY_OSM); // create account instance
  console.log(accountosm.address);

  // ================================ Contract ================================
  // create contract instance
  const contractosm = cfx.Contract({
    abi: require('./contract/OSM_ORI-abi.json'),
    address: '${osm_addr}',
  });
  const receiptosm = await contractosm.poke()
  .sendTransaction({from: accountosm,
                    gas: 10000000 })
  .confirmed();
  console.log(receiptosm);
}

main().catch(e => console.error(e));
END_MESSAGE
print {$osm_fh} $message;
close $osm_fh;
my $start = time();
system("node osmpoke.js");
my $end = time();
$total_time = $total_time + $end - $start;
system("rm -rf osmpoke.js");

my @a = (1..${num_nodes});
for(@a){
	print("SPOT $_ is being deployed\n");
    system("node deployspotter.js");
}
open( my $default_fh, "<", "deployreceipt.txt" ) or die $!;
my $node = 1;
while ( my $line = <$default_fh> ) {
    $line =~ s/\R//g;
    open( my $main_fh,    ">", "spotter_${node}_poke.js" ) or die $!;
    my $message = <<"END_MESSAGE";
const { Conflux } = require('js-conflux-sdk');

const PRIVATE_KEY_OSM = '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

async function main() {
  const cfx = new Conflux({
    url: 'http://localhost:12540',
    defaultGasPrice: 1,
    defaultGas: 1000000,
    logger: console,
  });

  console.log(cfx.defaultGasPrice); // 100
  console.log(cfx.defaultGas); // 1000000

  // ================================ Account =================================
  const accountosm = cfx.Account(PRIVATE_KEY_OSM); // create account instance
  console.log(accountosm.address);

  // ================================ Contract ================================
  // create contract instance
  const contractspot = cfx.Contract({
    abi: require('./contract/Spotter_ORI-abi.json'),
    address: '${line}',
  });

  const contractosm = cfx.Contract({
    abi: require('./contract/OSM_ORI-abi.json'),
    address: '${osm_addr}',
  });

  // deploy the contract, and get `contractCreated`
  const receiptspot = await contractspot.simple_poke(contractosm.address)
    .sendTransaction({from: accountosm})
    .confirmed();
  console.log(receiptspot);
}

main().catch(e => console.error(e));
END_MESSAGE
    print {$main_fh} $message;
    close $main_fh;
    my $start = time();
    system("node spotter_${node}_poke.js");
    my $end = time();
    $total_time = $total_time + $end - $start;
    system("rm -rf spotter_${node}_poke.js");
    if($node == ceil($num_nodes/2)){
        open($main_fh,    ">", "spotter_${node}_getdata.js" ) or die $!;
        $message = <<"END_MESSAGE";
const { Conflux } = require('js-conflux-sdk');

const PRIVATE_KEY_OSM = '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

async function main() {
  const cfx = new Conflux({
    url: 'http://localhost:12540',
    defaultGasPrice: 1,
    defaultGas: 1000000,
    logger: console,
  });

  console.log(cfx.defaultGasPrice); // 100
  console.log(cfx.defaultGas); // 1000000

  // ================================ Account =================================
  const accountosm = cfx.Account(PRIVATE_KEY_OSM); // create account instance
  console.log(accountosm.address);

  // ================================ Contract ================================
  // create contract instance
  const contractspot = cfx.Contract({
    abi: require('./contract/Spotter_ORI-abi.json'),
    address: '${line}',
  });

  // deploy the contract, and get `contractCreated`
  await contractspot.getPrice();
}

main().catch(e => console.error(e));
END_MESSAGE
        print {$main_fh} $message;
        close $main_fh;
    }
    $node = $node + 1;
}
system("rm -rf deployreceipt.txt");
close $default_fh;

print("Poke Time: $total_time secs\n");
=for comment
running order:
node deploydsval.js
node deployosm.js //deploy with dsvalue contract address
node dsvalpoke.js
node osmsethop.js
node osmpokeandread.js
./spotsdeploypoke.pl <num of nodes> <osm address> //to get time comsumption
=cut


