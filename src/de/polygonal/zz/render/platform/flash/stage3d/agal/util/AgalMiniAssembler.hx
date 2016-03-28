/*
Copyright (c) 2011, Adobe Systems Incorporated
All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright notice, 
this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the 
documentation and/or other materials provided with the distribution.

* Neither the name of Adobe Systems Incorporated nor the names of its 
contributors may be used to endorse or promote products derived from 
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR 
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
package de.polygonal.zz.render.platform.flash.stage3d.agal.util;

import flash.Lib;
import flash.utils.ByteArray;
import flash.utils.Endian;
import haxe.ds.StringMap;

using de.polygonal.zz.render.platform.flash.stage3d.agal.util.AgalMiniAssemblerHelper;

class AgalMiniAssembler
{
	public static var instance(get, never):AgalMiniAssembler;
	static function get_instance():AgalMiniAssembler return _instance == null ? (_instance = new AgalMiniAssembler()) : _instance;
	static var _instance:AgalMiniAssembler = null;
	
	public static var debugEnabled = false;
	public static var verbose = false;
	
	public var error(default, null) = "";
	static var initialized = false;
	
	function new()
	{
		init();
	}
	
	public function assemble(mode:String, source:String, version = 1, ignorelimits = false):ByteArray
	{
		var start = Lib.getTimer();
		
		var agalcode = new ByteArray();
		error = "";
		
		var isFrag = false;
		
		if (mode == FRAGMENT)
			isFrag = true;
		else if (mode != VERTEX)
			error = "ERROR: mode needs to be \"" + FRAGMENT + "\" or \"" + VERTEX + "\" but is \"" + mode + "\".";
		
		agalcode.endian = Endian.LITTLE_ENDIAN;
		agalcode.writeByte(0xA0);				//tag version
		agalcode.writeUnsignedInt(version);		//Agal version, big endian, bit pattern will be 0x01000000
		agalcode.writeByte(0xA1);				//tag program id
		agalcode.writeByte(isFrag ? 1:0);		//vertex or fragment
		
		initregmap(version, ignorelimits);
		
		var lines:Array<String> = source.replace("[\\f\\n\\r\\v]+", "g", "\n").split("\n");
		var nest:Int = 0;
		var nops:Int = 0;
		var i:Int, j:Int;
		var lng:Int = lines.length;
		
		i = -1;
		while (++i < lng && error == "")
		{
			var line:String = new String(lines[i]);
			line = line.replace("^\\s+|\\s+$", "g", "");
			
			//remove comments
			var startcomment = line.search("//");
			if (startcomment != -1)
				line = line.slice(0, startcomment);
			
			//grab options
			var optsi = line.search("<.*>", "g");
			var opts:Array<String> = null;
			if (optsi != -1)
			{
				opts = line.slice(optsi).match("([\\w\\.\\-\\+]+)", "gi");
				line = line.slice(0, optsi);
			}
			
			//find opcode
			var opCode:Array<String> = line.match("^\\w{3}", "ig");
			if (opCode == null)
			{
				if (line.length >= 3)
					trace("warning: bad line "+i+": "+lines[i]);
				continue;
			}
			var opFound = OPMAP.get(opCode[0]);
			
			//if debug is enabled, output the opcodes
			if (debugEnabled)
				trace(opFound);
			
			if (opFound == null)
			{
				if (line.length >= 3)
					trace("warning: bad line "+i+": "+lines[i]);
				continue;
			}
			
			line = line.slice(line.search(opFound.name) + opFound.name.length);
			
			if ((opFound.flags & OP_VERSION2 != 0) && version<2)
			{
				error = "error: opcode requires version 2.";
				break;
			}
			
			if ((opFound.flags & OP_VERT_ONLY != 0) && isFrag)
			{
				error = "error: opcode is only allowed in vertex programs.";
				break;
			}
			
			if ((opFound.flags & OP_FRAG_ONLY != 0) && !isFrag)
			{
				error = "error: opcode is only allowed in fragment programs.";
				break;
			}
			if (verbose)
				trace("emit opcode=" + opFound);
			
			agalcode.writeUnsignedInt(opFound.emitCode);
			nops++;
			
			if (nops > MAX_OPCODES)
			{
				error = "error: too many opcodes. maximum is "+MAX_OPCODES+".";
				break;
			}
			
			//get operands, use regexp
			var regs:Array<String> = null;
			
			//will match both syntax
			regs = line.match("vc\\[([vof][acostdip]?)(\\d*)?(\\.[xyzw](\\+\\d{1,3})?)?\\](\\.[xyzw]{1,4})?|([vof][acostdip]?)(\\d*)?(\\.[xyzw]{1,4})?", "gi");
			
			if ((regs == null) || regs.length != Std.int(opFound.numRegister))
			{
				error = "error: wrong number of operands. found "+regs.length+" but expected "+opFound.numRegister+".";
				break;
			}
			
			var badreg = false;
			var pad:UInt = 64 + 64 + 32;
			var regLength:UInt = regs.length;
			var k:Int;
			
			for (j in 0...regLength)
			{
				var isRelative = false;
				var relreg:Array<String> = regs[ j ].match("\\[.*\\]", "ig");
				if ((relreg != null) && relreg.length > 0)
				{
					regs[j] = StringTools.replace(regs[j], relreg[0], "0");
					if (verbose)
						trace("IS REL");
					isRelative = true;
				}
				
				var res:Array<String> = regs[j].match("^\\b[A-Za-z]{1,2}", "ig");
				if (res == null)
				{
					error = "error: could not parse operand "+j+" ("+regs[j]+").";
					badreg = true;
					break;
				}
				var regFound = REGMAP.get(res[ 0 ]);
				
				//if debug is enabled, output the registers
				if (debugEnabled)
					trace(regFound);
				
				if (regFound == null)
				{
					error = "error: could not find register name for operand "+j+" ("+regs[j]+").";
					badreg = true;
					break;
				}
				
				if (isFrag)
				{
					if ((regFound.flags & REG_FRAG == 0))
					{
						error = "error: register operand "+j+" ("+regs[j]+") only allowed in vertex programs.";
						badreg = true;
						break;
					}
					if (isRelative)
					{
						error = "error: register operand "+j+" ("+regs[j]+") relative adressing not allowed in fragment programs.";
						badreg = true;
						break;
					}
				}
				else
				{
					if ((regFound.flags & REG_VERT == 0))
					{
						error = "error: register operand "+j+" ("+regs[j]+") only allowed in fragment programs.";
						badreg = true;
						break;
					}
				}
				
				regs[j] = regs[j].slice(regs[j].search(regFound.name) + regFound.name.length);
				//trace("REGNUM: " +regs[j]);
				var idxmatch:Array<String> = isRelative ? relreg[0].match("\\d+"):regs[j].match("\\d+");
				var regidx = 0;
				
				if (idxmatch != null)
					regidx = Std.parseInt(idxmatch[0]);
				
				if (Std.int(regFound.range) < regidx)
				{
					error = "error: register operand "+j+" ("+regs[j]+") index exceeds limit of "+(regFound.range+1)+".";
					badreg = true;
					break;
				}
				
				var regmask:UInt = 0;
				var maskmatch:Array<String> = regs[j].match("(\\.[xyzw]{1,4})");
				var isDest:Bool = (j == 0 &&(opFound.flags & OP_NO_DEST == 0));
				var isSampler:Bool = (j == 2 &&(opFound.flags & OP_SPECIAL_TEX != 0));
				var reltype:UInt = 0;
				var relsel:UInt = 0;
				var reloffset:Int = 0;
				
				if (isDest && isRelative)
				{
					error = "error: relative can not be destination";
					badreg = true;
					break;
				}
				
				if (maskmatch != null)
				{
					regmask = 0;
					var cv:UInt = 0;
					var maskLength:UInt = maskmatch[0].length;
					k = 1;
					while (k < Std.int(maskLength))
					{
						cv = maskmatch[0].charCodeAt(k) - "x".charCodeAt(0);
						if (cv > 2)
							cv = 3;
						if (isDest)
							regmask |= 1 << cv;
						else
							regmask |= cv <<((k - 1) << 1);
						k++;
					}
					if (!isDest)
					{
						while (k <= 4)
						{
							regmask |= cv <<((k - 1) << 1); //repeat last
							k++;
						}
					}
				}
				else
				{
					regmask = isDest ? 0xF:0xE4; //id swizzle or mask
				}
				
				if (isRelative)
				{
					var relname:Array<String> = relreg[0].match("[A-Za-z]{1,2}", "ig");
					var regFoundRel:Register = REGMAP.get(relname[0]);
					if (regFoundRel == null)
					{
						error = "error: bad index register";
						badreg = true;
						break;
					}
					reltype = regFoundRel.emitCode;
					var selmatch:Array<String> = relreg[0].match("(\\.[xyzw]{1,1})");
					if (selmatch.length==0)
					{
						error = "error: bad index register select";
						badreg = true;
						break;
					}
					relsel = selmatch[0].charCodeAt(1) - "x".charCodeAt(0);
					if (relsel > 2)
						relsel = 3;
					var relofs:Array<String> = relreg[0].match("\\+\\d{1,3}", "ig");
					if (relofs.length > 0)
						reloffset = Std.parseInt(relofs[0]);
					if (reloffset < 0 || reloffset > 255)
					{
						error = "error: index offset "+reloffset+" out of bounds. [0..255]";
						badreg = true;
						break;
					}
					if (verbose)
						trace("RELATIVE: type="+reltype+"=="+relname[0]+" sel="+relsel+"=="+selmatch[0]+" idx="+regidx+" offset="+reloffset);
				}
				
				if (verbose)
					trace("  emit argcode="+regFound+"["+regidx+"]["+regmask+"]");
				if (isDest)
				{
					agalcode.writeShort(regidx);
					agalcode.writeByte(regmask);
					agalcode.writeByte(regFound.emitCode);
					pad -= 32;
				} else
				{
					if (isSampler)
					{
						if (verbose)
							trace("  emit sampler");
						var samplerbits:UInt = 5; //type 5
						var optsLength:UInt = opts == null ? 0:opts.length;
						var bias:Float = 0;
						k = 0;
						while (k < Std.int(optsLength))
						{
							if (verbose)
								trace("    opt: "+opts[k]);
							var optfound:Sampler = SAMPLEMAP.get(opts[k]);
							if (optfound == null)
							{
								//todo check that it"s a number...
								//trace("Warning, unknown sampler option: "+opts[k]);
								bias = Std.parseFloat(opts[k]);
								if (verbose)
									trace("    bias: " + bias);
							}
							else
							{
								if (optfound.flag != SAMPLER_SPECIAL_SHIFT)
									samplerbits &= ~(0xF << optfound.flag);
							
								//samplerbits |= UInt(optfound.mask) << UInt(optfound.flag);
								samplerbits |= optfound.mask  << optfound.flag ;
							}
							k++;
						}
						agalcode.writeShort(regidx);
						agalcode.writeByte(Std.int(bias*8.0));
						agalcode.writeByte(0);
						agalcode.writeUnsignedInt(samplerbits);
						
						if (verbose)
							trace("    bits: " +(samplerbits - 5));
						pad -= 64;
					}
					else
					{
						if (j == 0)
						{
							agalcode.writeUnsignedInt(0);
							pad -= 32;
						}
						agalcode.writeShort(regidx);
						agalcode.writeByte(reloffset);
						agalcode.writeByte(regmask);
						agalcode.writeByte(regFound.emitCode);
						agalcode.writeByte(reltype);
						agalcode.writeShort(isRelative ?(relsel |(1 << 15)):0);
						
						pad -= 64;
					}
				}
			}
			
			//pad unused regs
			j = 0;
			while (j < Std.int(pad))
			{
				agalcode.writeByte(0);
				j += 8;
			}
			
			if (badreg)
				break;
		}
		
		if (error != "")
		{
			error += "\n  at line " + i + " " + lines[i];
			agalcode.length = 0;
			trace(error);
		}
		
		//trace the bytecode bytes if debugging is enabled
		if (debugEnabled)
		{
			var dbgLine = "generated bytecode:";
			var agalLength:UInt = agalcode.length;
			var index = 0;
			while (index < Std.int(agalLength))
			{
				if ((index % 16) == 0)
					dbgLine += "\n";
				if ((index % 4) == 0)
					dbgLine += " ";
				
				var byteStr:String = StringTools.hex(agalcode[ index ]);
				if (byteStr.length < 2)
					byteStr = "0" + byteStr;
				
				dbgLine += byteStr;
				index++;
			}
			trace(dbgLine);
		}
		
		if (verbose)
			trace("AgalMiniAssembler.assemble time: " + ((Lib.getTimer() - start) / 1000) + "s");
		
		return agalcode;
	}
	
	function initregmap(version:UInt, ignorelimits:Bool)
	{
		//version changes limits
		REGMAP.set(VA, new Register(VA, "vertex attribute",		0x0,	ignorelimits?1024:7,						REG_VERT | REG_READ));
		REGMAP.set(VC, new Register(VC, "vertex constant",		0x1,	ignorelimits?1024:(version==1?127:250),		REG_VERT | REG_READ));
		REGMAP.set(VT, new Register(VT, "vertex temporary",		0x2,	ignorelimits?1024:(version==1?7:27),		REG_VERT | REG_WRITE | REG_READ));
		REGMAP.set(VO, new Register(VO, "vertex output",		0x3,	ignorelimits?1024:0,						REG_VERT | REG_WRITE));
		REGMAP.set(VI, new Register(VI,	"varying",				0x4,	ignorelimits?1024:(version==1?7:11),		REG_VERT | REG_FRAG | REG_READ | REG_WRITE));
		REGMAP.set(FC, new Register(FC,	"fragment constant",	0x1,	ignorelimits?1024:(version==1?27:63),		REG_FRAG | REG_READ));
		REGMAP.set(FT, new Register(FT,	"fragment temporary",	0x2,	ignorelimits?1024:(version==1?7:27),		REG_FRAG | REG_WRITE | REG_READ));
		REGMAP.set(FS, new Register(FS,	"texture sampler",		0x5,	ignorelimits?1024:7,						REG_FRAG | REG_READ));
		REGMAP.set(FO, new Register(FO,	"fragment output",		0x3,	ignorelimits?1024:(version==1?0:3),			REG_FRAG | REG_WRITE));
		REGMAP.set(FD, new Register(FD,	"fragment depth output",0x6,	ignorelimits?1024:(version==1?-1:0),		REG_FRAG | REG_WRITE));
		
		//aliases
		REGMAP.set("op", REGMAP.get(VO));
		REGMAP.set("i" , REGMAP.get(VI));
		REGMAP.set("v" , REGMAP.get(VI));
		REGMAP.set("oc", REGMAP.get(FO));
		REGMAP.set("od", REGMAP.get(FD));
		REGMAP.set("fi", REGMAP.get(VI));
	}
	
	static function init()
	{
		initialized = true;
		
		OPMAP = new StringMap<OpCode>();
		REGMAP = new StringMap<Register>();
		SAMPLEMAP = new StringMap<Sampler>();
		
		//fill the dictionaries with opcodes and registers
		OPMAP.set(MOV, new OpCode(MOV, 2, 0x00, 0));
		OPMAP.set(ADD, new OpCode(ADD, 3, 0x01, 0));
		OPMAP.set(SUB, new OpCode(SUB, 3, 0x02, 0));
		OPMAP.set(MUL, new OpCode(MUL, 3, 0x03, 0));
		OPMAP.set(DIV, new OpCode(DIV, 3, 0x04, 0));
		OPMAP.set(RCP, new OpCode(RCP, 2, 0x05, 0));
		OPMAP.set(MIN, new OpCode(MIN, 3, 0x06, 0));
		OPMAP.set(MAX, new OpCode(MAX, 3, 0x07, 0));
		OPMAP.set(FRC, new OpCode(FRC, 2, 0x08, 0));
		OPMAP.set(SQT, new OpCode(SQT, 2, 0x09, 0));
		OPMAP.set(RSQ, new OpCode(RSQ, 2, 0x0A, 0));
		OPMAP.set(POW, new OpCode(POW, 3, 0x0B, 0));
		OPMAP.set(LOG, new OpCode(LOG, 2, 0x0C, 0));
		OPMAP.set(EXP, new OpCode(EXP, 2, 0x0D, 0));
		OPMAP.set(NRM, new OpCode(NRM, 2, 0x0E, 0));
		OPMAP.set(SIN, new OpCode(SIN, 2, 0x0F, 0));
		OPMAP.set(COS, new OpCode(COS, 2, 0x10, 0));
		OPMAP.set(CRS, new OpCode(CRS, 3, 0x11, 0));
		OPMAP.set(DP3, new OpCode(DP3, 3, 0x12, 0));
		OPMAP.set(DP4, new OpCode(DP4, 3, 0x13, 0));
		OPMAP.set(ABS, new OpCode(ABS, 2, 0x14, 0));
		OPMAP.set(NEG, new OpCode(NEG, 2, 0x15, 0));
		OPMAP.set(SAT, new OpCode(SAT, 2, 0x16, 0));
		OPMAP.set(M33, new OpCode(M33, 3, 0x17, OP_SPECIAL_MATRIX));
		OPMAP.set(M44, new OpCode(M44, 3, 0x18, OP_SPECIAL_MATRIX));
		OPMAP.set(M34, new OpCode(M34, 3, 0x19, OP_SPECIAL_MATRIX));
		OPMAP.set(DDX, new OpCode(DDX, 2, 0x1A, OP_VERSION2 | OP_FRAG_ONLY));
		OPMAP.set(DDY, new OpCode(DDY, 2, 0x1B, OP_VERSION2 | OP_FRAG_ONLY));
		OPMAP.set(IFE, new OpCode(IFE, 2, 0x1C, OP_NO_DEST | OP_VERSION2 | OP_INCNEST | OP_SCALAR));
		OPMAP.set(INE, new OpCode(INE, 2, 0x1D, OP_NO_DEST | OP_VERSION2 | OP_INCNEST | OP_SCALAR));
		OPMAP.set(IFG, new OpCode(IFG, 2, 0x1E, OP_NO_DEST | OP_VERSION2 | OP_INCNEST | OP_SCALAR));
		OPMAP.set(IFL, new OpCode(IFL, 2, 0x1F, OP_NO_DEST | OP_VERSION2 | OP_INCNEST | OP_SCALAR));
		OPMAP.set(ELS, new OpCode(ELS, 0, 0x20, OP_NO_DEST | OP_VERSION2 | OP_INCNEST | OP_DECNEST | OP_SCALAR));
		OPMAP.set(EIF, new OpCode(EIF, 0, 0x21, OP_NO_DEST | OP_VERSION2 | OP_DECNEST | OP_SCALAR));
		
		//space
		OPMAP.set(TED, new OpCode(TED, 3, 0x26, OP_FRAG_ONLY | OP_SPECIAL_TEX | OP_VERSION2));
		OPMAP.set(KIL, new OpCode(KIL, 1, 0x27, OP_NO_DEST | OP_FRAG_ONLY));
		OPMAP.set(TEX, new OpCode(TEX, 3, 0x28, OP_FRAG_ONLY | OP_SPECIAL_TEX));
		OPMAP.set(SGE, new OpCode(SGE, 3, 0x29, 0));
		OPMAP.set(SLT, new OpCode(SLT, 3, 0x2A, 0));
		OPMAP.set(SGN, new OpCode(SGN, 2, 0x2B, 0));
		OPMAP.set(SEQ, new OpCode(SEQ, 3, 0x2C, 0));
		OPMAP.set(SNE, new OpCode(SNE, 3, 0x2D, 0));
	
		SAMPLEMAP.set(RGBA,          new Sampler(RGBA,          SAMPLER_TYPE_SHIFT,    0));
		SAMPLEMAP.set(DXT1,          new Sampler(DXT1,          SAMPLER_TYPE_SHIFT,    1));
		SAMPLEMAP.set(DXT5,          new Sampler(DXT5,          SAMPLER_TYPE_SHIFT,    2));
		SAMPLEMAP.set(VIDEO,         new Sampler(VIDEO,         SAMPLER_TYPE_SHIFT,    3));
		SAMPLEMAP.set(D2,            new Sampler(D2,            SAMPLER_DIM_SHIFT,     0));
		SAMPLEMAP.set(D3,            new Sampler(D3,            SAMPLER_DIM_SHIFT,     2));
		SAMPLEMAP.set(CUBE,          new Sampler(CUBE,          SAMPLER_DIM_SHIFT,     1));
		SAMPLEMAP.set(MIPNEAREST,    new Sampler(MIPNEAREST,    SAMPLER_MIPMAP_SHIFT,  1));
		SAMPLEMAP.set(MIPLINEAR,     new Sampler(MIPLINEAR,     SAMPLER_MIPMAP_SHIFT,  2));
		SAMPLEMAP.set(MIPNONE,       new Sampler(MIPNONE,       SAMPLER_MIPMAP_SHIFT,  0));
		SAMPLEMAP.set(NOMIP,         new Sampler(NOMIP,         SAMPLER_MIPMAP_SHIFT,  0));
		SAMPLEMAP.set(NEAREST,       new Sampler(NEAREST,       SAMPLER_FILTER_SHIFT,  0));
		SAMPLEMAP.set(LINEAR,        new Sampler(LINEAR,        SAMPLER_FILTER_SHIFT,  1));
		SAMPLEMAP.set(CENTROID,      new Sampler(CENTROID,      SAMPLER_SPECIAL_SHIFT, 1 << 0));
		SAMPLEMAP.set(SINGLE,        new Sampler(SINGLE,        SAMPLER_SPECIAL_SHIFT, 1 << 1));
		SAMPLEMAP.set(IGNORESAMPLER, new Sampler(IGNORESAMPLER, SAMPLER_SPECIAL_SHIFT, 1 << 2));
		SAMPLEMAP.set(REPEAT,        new Sampler(REPEAT,        SAMPLER_REPEAT_SHIFT,  1));
		SAMPLEMAP.set(WRAP,          new Sampler(WRAP,          SAMPLER_REPEAT_SHIFT,  1));
		SAMPLEMAP.set(CLAMP,         new Sampler(CLAMP,         SAMPLER_REPEAT_SHIFT,  0));
	}
	
	static var OPMAP:StringMap<OpCode>;
	static var REGMAP:StringMap<Register>;
	static var SAMPLEMAP:StringMap<Sampler>;
	
	inline static var MAX_NESTING = 4;
	inline static var MAX_OPCODES = 2048;
	
	inline static var FRAGMENT = "fragment";
	inline static var VERTEX   = "vertex";
	
	//masks and shifts
	inline static var SAMPLER_TYPE_SHIFT    = 8;
	inline static var SAMPLER_DIM_SHIFT     = 12;
	inline static var SAMPLER_SPECIAL_SHIFT = 16;
	inline static var SAMPLER_REPEAT_SHIFT  = 20;
	inline static var SAMPLER_MIPMAP_SHIFT  = 24;
	inline static var SAMPLER_FILTER_SHIFT  = 28;
	
	//regmap flags
	inline static var REG_WRITE = 0x1;
	inline static var REG_READ  = 0x2;
	inline static var REG_FRAG  = 0x20;
	inline static var REG_VERT  = 0x40;
	
	//opmap flags
	inline static var OP_SCALAR         = 0x1;
	inline static var OP_SPECIAL_TEX    = 0x8;
	inline static var OP_SPECIAL_MATRIX = 0x10;
	inline static var OP_FRAG_ONLY      = 0x20;
	inline static var OP_VERT_ONLY      = 0x40;
	inline static var OP_NO_DEST        = 0x80;
	inline static var OP_VERSION2       = 0x100;
	inline static var OP_INCNEST        = 0x200;
	inline static var OP_DECNEST        = 0x400;
	
	//opcodes
	inline static var MOV = "mov";
	inline static var ADD = "add";
	inline static var SUB = "sub";
	inline static var MUL = "mul";
	inline static var DIV = "div";
	inline static var RCP = "rcp";
	inline static var MIN = "min";
	inline static var MAX = "max";
	inline static var FRC = "frc";
	inline static var SQT = "sqt";
	inline static var RSQ = "rsq";
	inline static var POW = "pow";
	inline static var LOG = "log";
	inline static var EXP = "exp";
	inline static var NRM = "nrm";
	inline static var SIN = "sin";
	inline static var COS = "cos";
	inline static var CRS = "crs";
	inline static var DP3 = "dp3";
	inline static var DP4 = "dp4";
	inline static var ABS = "abs";
	inline static var NEG = "neg";
	inline static var SAT = "sat";
	inline static var M33 = "m33";
	inline static var M44 = "m44";
	inline static var M34 = "m34";
	inline static var DDX = "ddx";
	inline static var DDY = "ddy";
	inline static var IFE = "ife";
	inline static var INE = "ine";
	inline static var IFG = "ifg";
	inline static var IFL = "ifl";
	inline static var ELS = "els";
	inline static var EIF = "eif";
	inline static var TED = "ted";
	inline static var KIL = "kil";
	inline static var TEX = "tex";
	inline static var SGE = "sge";
	inline static var SLT = "slt";
	inline static var SGN = "sgn";
	inline static var SEQ = "seq";
	inline static var SNE = "sne";
	
	inline static var VA = "va";
	inline static var VC = "vc";
	inline static var VT = "vt";
	inline static var VO = "vo";
	inline static var VI = "vi";
	inline static var FC = "fc";
	inline static var FT = "ft";
	inline static var FS = "fs";
	inline static var FO = "fo";
	inline static var FD = "fd";
	
	inline static var D2            = "2d";
	inline static var D3            = "3d";
	inline static var CUBE          = "cube";
	inline static var MIPNEAREST    = "mipnearest";
	inline static var MIPLINEAR     = "miplinear";
	inline static var MIPNONE       = "mipnone";
	inline static var NOMIP         = "nomip";
	inline static var NEAREST       = "nearest";
	inline static var LINEAR        = "linear";
	inline static var CENTROID      = "centroid";
	inline static var SINGLE        = "single";
	inline static var IGNORESAMPLER = "ignoresampler";
	inline static var REPEAT        = "repeat";
	inline static var WRAP          = "wrap";
	inline static var CLAMP         = "clamp";
	inline static var RGBA          = "rgba";
	inline static var DXT1          = "dxt1";
	inline static var DXT5          = "dxt5";
	inline static var VIDEO         = "video";
}

private class OpCode
{
	public var emitCode:UInt;
	public var flags:UInt;
	public var name:String;
	public var numRegister:UInt;
	
	public function new(name:String, numRegister:UInt, emitCode:UInt, flags:UInt)
	{
		this.name = name;
		this.numRegister = numRegister;
		this.emitCode = emitCode;
		this.flags = flags;
	}
	
	public function toString():String
	{
		return '[OpCode name=$name, numRegister=$numRegister, emitCode=$emitCode, flags=$flags]';
	}
}

private class Register
{
	public var emitCode:UInt;
	public var name:String;
	public var longName:String;
	public var flags:UInt;
	public var range:UInt;
	
	public function new(name:String, longName:String, emitCode:UInt, range:UInt, flags:UInt)
	{
		this.name = name;
		this.longName = longName;
		this.emitCode = emitCode;
		this.range = range;
		this.flags = flags;
	}
	
	public function toString():String
	{
		return '[Register name=$name, longName=$longName, emitCode=$emitCode, range=$range, flags=$flags]';
	}
}

private class Sampler
{
	public var flag:UInt;
	public var mask:UInt;
	public var name:String;
	
	public function new(name:String, flag:UInt, mask:UInt)
	{
		this.name = name;
		this.flag = flag;
		this.mask = mask;
	}
	
	public function toString():String
	{
		return '[Sampler name=$name, flag=$flag, mask=$mask]';
	}
}