################################################
# HMRPC Device Handler
# Written by Oliver Wagner <owagner@vapor.com>
#
# V0.5
#
################################################
#
# This module handles individual devices via the
# HMRPC provider.
#
package main;

use strict;
use warnings;

sub
HMDEV_Initialize($)
{
  my ($hash) = @_;

  $hash->{Match}     = "^HMDEV .* .* .*";
  $hash->{DefFn}     = "HMDEV_Define";
  $hash->{ParseFn}   = "HMDEV_Parse";
  $hash->{SetFn}     = "HMDEV_Set";
  $hash->{GetFn}     = "HMDEV_Get";
  $hash->{AttrList}  = "IODev " . $readingFnAttributes;
}

#############################
sub
HMDEV_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
  my $name = $hash->{NAME};

  return "wrong syntax: define <name> HMDEV deviceaddress" if int(@a)!=3;
  
  my $addr=$a[2];

  $hash->{hmaddr}=$addr;
  $modules{HMDEV}{defptr}{$addr} = $hash;
  AssignIoPort($hash);
  
  if($hash->{IODev}->{NAME})
  {
  	Log 5,"Assigned $name to $hash->{IODev}->{NAME}";
  }
 
  return undef;
}



#############################
sub
HMDEV_Parse($$)
{
  my ($hash, $msg) = @_;
  
  my @mp=split(" ",$msg);
  my $addr=$mp[1];
  my $attrid=$mp[2];
  
  $hash=$modules{HMDEV}{defptr}{$addr};
  
  if(!$hash)
  {
  	# If not explicitely defined, reroute this event to the main device
  	# with a suffixed attribute name
  	$addr=~s/:([0-9]{1,2})//;
  	my $subdev=$1;
  	if($subdev>0)
  	{
  		$attrid.="_$subdev";
  	}
  	$hash=$modules{HMDEV}{defptr}{$addr};
  }
  
  if(!$hash)
  {
  	  Log(2,"Received callback for unknown device $msg");
  	  # Need to rewrite the device name here
  	  my $safe_name = "HMDEV_$addr";
  	  $safe_name =~ s/[^A-Za-z0-9.:_]/_/g;
  	  return "UNDEFINED $safe_name HMDEV $addr";
  }
  
  # Let's see whether we can update our devinfo now
  if(!defined $hash->{devinfo})
  {
  	  $hash->{hmdevinfo}=$hash->{IODev}{devicespecs}{$addr};
	  $hash->{hmdevtype}=$hash->{hmdevinfo}{TYPE};	  
  }
  
  #
  # Ok update the relevant reading
  #
  readingsSingleUpdate($hash, $attrid, $mp[3], 1);
  
  return $hash->{NAME};
}

################################
sub
HMDEV_Set($@)
{
	my ($hash, @a) = @_;

	return "Unknown argument ? choose one of " if ($a[1] eq "?");

	return "invalid set call @a" if(@a != 3 && @a != 4);

	my $hmaddr = $hash->{hmaddr};

	# If this is a main device and the set parameter contains a _sub postfix, rewrite this
	# to be a non-postfix'ed set on the subdevice address
	unless($hash->{hmaddr} =~ /:\d+$/) {
		if($a[-2] =~ /(.*)_(\d+)$/) {
			$hmaddr = $hmaddr . ":" . $2;
			$a[-2] = $1;
		}
	}

	# We delegate this call to the HMRPC IODev, after having added the device address
	if(@a==4)
	{
		return HMRPC_Set($hash->{IODev},$hash->{IODev}->{NAME},$hmaddr,$a[1],$a[2],$a[3]);
	}
	else
	{
		return HMRPC_Set($hash->{IODev},$hash->{IODev}->{NAME},$hmaddr,$a[1],$a[2]);
	}
}

################################
sub
HMDEV_Get($@)
{
	my ($hash, @a) = @_;

	return "Unknown argument ? choose one of " if ($a[1] eq "?");

	return "argument missing, usage is <attribute> @a" if(@a!=2);
	# Like set, we simply delegate to the HMPRC IODev here
	return HMRPC_Get($hash->{IODev},$hash->{IODev}->{NAME},$hash->{hmaddr},$a[1]);
}

1;
