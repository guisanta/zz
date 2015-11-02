package de.polygonal.zz.texture;

import de.polygonal.core.util.Assert.assert;
import de.polygonal.zz.data.*;
import de.polygonal.zz.render.*;
import de.polygonal.zz.render.effect.*;
import de.polygonal.zz.texture.*;
import de.polygonal.zz.texture.atlas.TextureAtlas;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat;
import haxe.ds.IntMap;

class TextureLib
{
	static var mRenderer:Renderer;
	static var mImageLut = new IntMap<ImageData>();
	static var mTextureLut = new IntMap<Texture>();
	
	public static function setRenderer(renderer:Renderer)
	{
		mRenderer = renderer;
	}
	
	public static function allocateTexture(id:Int, image:ImageData, ?pma:Bool = true, ?format:TextureAtlasFormat):Texture
	{
		assert(mRenderer != null);
		assert(!mImageLut.exists(id), "image [$id] was already mapped to the given id");
		
		mImageLut.set(id, image);
		
		var texture = new Texture();
		texture.isAlphaPremultiplied = pma;
		texture.setImageData(image, mRenderer.supportsNonPowerOfTwoTextures);
		
		assert(!mTextureLut.exists(id));
		mTextureLut.set(id, texture);
		
		L.d('texture [$id] allocated');
		
		if (format != null) texture.atlas = new TextureAtlas(texture, format.getAtlas());
		
		return texture;
	}
	
	#if flash
	public static function allocateAtfTexture(id:Int, bytes:flash.utils.ByteArray, ?format:TextureAtlasFormat):Texture
	{
		//TODO 
		//store for release
		//assert(!mImageLut.exists(id), "image [$id] was already mapped to the given id");
		//mImageLut.set(id, image);
		
		var texture = new Texture();
		texture.setAtfData(bytes);
		
		assert(!mTextureLut.exists(id));
		mTextureLut.set(id, texture);
		
		L.d('texture [$id] allocated');
		
		if (format != null) texture.atlas = new TextureAtlas(texture, format.getAtlas());
		
		return texture;
	}
	#end
	
	inline public static function getTexture(id:Int):Texture
	{
		assert(mTextureLut.exists(id), 'texture [$id] does not exist, call allocateTexture() first');
		return mTextureLut.get(id);
	}
	
	inline public static function isTextureAllocated(id:Int):Bool
	{
		return mTextureLut.exists(id);
	}
	
	public static function releaseTexture(id:Int)
	{
		assert(mTextureLut.exists(id), 'texture [$id] does not exist');
		
		assert(mImageLut.exists(id));
		var imageData = mImageLut.get(id);
		mImageLut.remove(id);
		
		var texture = getTexture(id);
		mTextureLut.remove(id);
		texture.free();
	}
}