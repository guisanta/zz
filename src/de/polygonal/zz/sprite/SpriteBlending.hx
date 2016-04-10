/*
Copyright (c) 2014 Michael Baczynski, http://www.polygonal.de

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
package de.polygonal.zz.sprite;

import de.polygonal.zz.scene.AlphaBlendState;
import de.polygonal.zz.scene.GlobalStateType;

@:allow(de.polygonal.zz.sprite.SpriteBase)
class SpriteBlending
{
	var mSprite:SpriteBase;
	
	public function new(sprite:SpriteBase)
	{
		mSprite = sprite;
	}
	
	public var current(get, never):String;
	function get_current():String
	{
		var o = mSprite.sgn.getGlobalState(GlobalStateType.AlphaBlend);
		if (o == null) return "Inherit";
		return Std.string(o.as(AlphaBlendState).alphaBlendMode);
	}
	
	public function setInherit():SpriteBase
	{
		mSprite.sgn.removeGlobalState(GlobalStateType.AlphaBlend);
		return mSprite;
	}
	
	public function setMultiply():SpriteBase
	{
		mSprite.sgn.setGlobalState(AlphaBlendState.PRESET_MULTIPLY);
		return mSprite;
	}
	
	public function setAdd():SpriteBase
	{
		mSprite.sgn.setGlobalState(AlphaBlendState.PRESET_ADD);
		return mSprite;
	}
	
	public function setScreen():SpriteBase
	{
		mSprite.sgn.setGlobalState(AlphaBlendState.PRESET_SCREEN);
		return mSprite;
	}
	
	public function setNormal():SpriteBase
	{
		mSprite.sgn.setGlobalState(AlphaBlendState.PRESET_NORMAL);
		return mSprite;
	}
	
	public function setNone():SpriteBase
	{
		mSprite.sgn.setGlobalState(AlphaBlendState.PRESET_NONE);
		return mSprite;
	}
}