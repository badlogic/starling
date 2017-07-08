// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.textures;

import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display3D.Context3D;
import flash.display3D.Context3DProfile;
import flash.display3D.Context3DTextureFormat;
import flash.display3D.textures.RectangleTexture;
import flash.display3D.textures.TextureBase;
import flash.errors.ArgumentError;
import flash.display3D.textures.VideoTexture;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
#if flash
import flash.media.Camera;
#end
import flash.net.NetStream;
import flash.system.Capabilities;

import haxe.Constraints.Function;

import openfl.utils.ByteArray;
import openfl.Vector;

import starling.core.Starling;
import starling.errors.AbstractClassError;
import starling.errors.MissingContextError;
import starling.errors.NotSupportedError;
import starling.rendering.VertexData;
import starling.utils.MathUtil;
import starling.utils.MatrixUtil;
import starling.utils.SystemUtil;

/** <p>A texture stores the information that represents an image. It cannot be added to the
 *  display list directly; instead it has to be mapped onto a display object. In Starling,
 *  the most probably candidate for this job is the <code>Image</code> class.</p>
 *
 *  <strong>Creating a texture</strong>
 *
 *  <p>The <code>Texture</code> class is abstract, i.e. you cannot create instance of this
 *  class through its constructor. Instead, it offers a variety of factory methods, like
 *  <code>fromBitmapData</code> or <code>fromEmbeddedAsset</code>.</p>
 *
 *  <strong>Texture Formats</strong>
 *
 *  <p>Since textures can be created from a "BitmapData" object, Starling supports any bitmap
 *  format that is supported by Flash. And since you can render any Flash display object into
 *  a BitmapData object, you can use this to display non-Starling content in Starling - e.g.
 *  Shape objects.</p>
 *
 *  <p>Starling also supports ATF textures (Adobe Texture Format), which is a container for
 *  compressed texture formats that can be rendered very efficiently by the GPU. Refer to
 *  the Flash documentation for more information about this format.</p>
 *
 *  <p>Beginning with AIR 17, you can use Starling textures to show video content (if the
 *  current platform supports it; see "SystemUtil.supportsVideoTexture").
 *  The two factory methods "fromCamera" and "fromNetStream" allow you to make use of
 *  this feature.</p>
 *
 *  <strong>Mip Mapping</strong>
 *
 *  <p>MipMaps are scaled down versions of a texture. When an image is displayed smaller than
 *  its natural size, the GPU may display the mip maps instead of the original texture. This
 *  reduces aliasing and accelerates rendering. It does, however, also need additional memory;
 *  for that reason, mipmapping is disabled by default.</p>
 *
 *  <strong>Texture Frame</strong>
 *
 *  <p>The frame property of a texture allows you to let a texture appear inside the bounds of
 *  an image, leaving a transparent border around the texture. The frame rectangle is specified
 *  in the coordinate system of the texture (not the image):</p>
 *
 *  <listing>
 *  var frame:Rectangle = new Rectangle(-10, -10, 30, 30);
 *  var texture:Texture = Texture.fromTexture(anotherTexture, null, frame);
 *  var image:Image = new Image(texture);</listing>
 *
 *  <p>This code would create an image with a size of 30x30, with the texture placed at
 *  <code>x=10, y=10</code> within that image (assuming that 'anotherTexture' has a width and
 *  height of 10 pixels, it would appear in the middle of the image).</p>
 *
 *  <p>The texture atlas makes use of this feature, as it allows to crop transparent edges
 *  of a texture and making up for the changed size by specifying the original texture frame.
 *  Tools like <a href="http://www.texturepacker.com/">TexturePacker</a> use this to
 *  optimize the atlas.</p>
 *
 *  <strong>Texture Coordinates</strong>
 *
 *  <p>If, on the other hand, you want to show only a part of the texture in an image
 *  (i.e. to crop the the texture), you can either create a subtexture (with the method
 *  'Texture.fromTexture()' and specifying a rectangle for the region), or you can manipulate
 *  the texture coordinates of the image object. The method <code>image.setTexCoords</code>
 *  allows you to do that.</p>
 *
 *  <strong>Context Loss</strong>
 *
 *  <p>When the current rendering context is lost (which can happen on all platforms, but is
 *  especially common on Android and Windows), all texture data is destroyed. However,
 *  Starling will try to restore the textures. To do that, it will keep the bitmap
 *  and ATF data in memory - at the price of increased RAM consumption. You can optimize
 *  this behavior, though, by restoring the texture directly from its source, like in this
 *  example:</p>
 *
 *  <listing>
 *  var texture:Texture = Texture.fromBitmap(new EmbeddedBitmap());
 *  texture.root.onRestore = function():void
 *  {
 *      texture.root.uploadFromBitmap(new EmbeddedBitmap());
 *  };</listing>
 *
 *  <p>The <code>onRestore</code>-method will be called when the context was lost and the
 *  texture has been recreated (but is still empty). If you use the "AssetManager" class to
 *  manage your textures, this will be done automatically.</p>
 *
 *  @see starling.display.Image
 *  @see starling.utils.AssetManager
 *  @see starling.utils.SystemUtil
 *  @see TextureAtlas
 */
class Texture
{
    // helper objects
    private static var sDefaultOptions:TextureOptions = new TextureOptions();
    private static var sRectangle:Rectangle = new Rectangle();
    private static var sMatrix:Matrix = new Matrix();
    private static var sPoint:Point = new Point();

    /** @private */
    private function new()
    {
        
    }

    /** Disposes the underlying texture data. Note that not all textures need to be disposed:
     *  SubTextures (created with 'Texture.fromTexture') just reference other textures and
     *  and do not take up resources themselves; this is also true for textures from an
     *  atlas. */
    public function dispose():void
    {
        // override in subclasses
    }

    /** Creates a texture from any of the supported data types, using the specified options.
     *
     *  @param data     Either an embedded asset class, a Bitmap, BitmapData, or a ByteArray
     *                  with ATF data.
     *  @param options  Specifies options about the texture settings, e.g. the scale factor.
     *                  If left empty, the default options will be used.
     */
    public static function fromData(data:Dynamic, options:TextureOptions=null):Texture
    {
        var texture:Texture = null;

        if (Std.is(data, Bitmap))  data = cast(data, Bitmap).bitmapData;
        if (options == null) options = sDefaultOptions;

        if (Std.is(data, Class))
        {
            return fromEmbeddedAsset(cast data,
                options.mipMapping, options.optimizeForRenderToTexture,
                options.scale, options.format, options.forcePotTexture);
        }
        else if (Std.is(data, BitmapData))
        {
            return fromBitmapData(cast data,
                options.mipMapping, options.optimizeForRenderToTexture,
                options.scale, options.format, options.forcePotTexture,
                options.onReady);
        }
        else if (Std.is(data, ByteArrayData))
        {
            return fromAtfData(cast data,
                options.scale, options.mipMapping, options.onReady);
        }
        else
            throw new ArgumentError("Unsupported 'data' type: " + Type.getClassName(data));
    }

    /** Creates a texture object from an embedded asset class. Textures created with this
     *  method will be restored directly from the asset class in case of a context loss,
     *  which guarantees a very economic memory usage.
     *
     *  @param assetClass  must contain either a Bitmap or a ByteArray with ATF data.
     *  @param mipMapping  for Bitmaps, indicates if mipMaps will be created;
     *                     for ATF data, indicates if the contained mipMaps will be used.
     *  @param optimizeForRenderToTexture  indicates if this texture will be used as
     *                     render target.
     *  @param scale       the scale factor of the created texture.
     *  @param format      the context3D texture format to use. Ignored for ATF data.
     *  @param forcePotTexture  indicates if the underlying Stage3D texture should be created
     *                     as the power-of-two based "Texture" class instead of the more memory
     *                     efficient "RectangleTexture". (Only applicable to bitmaps; ATF
     *                     textures are always POT-textures, anyway.)
     */
    public static function fromEmbeddedAsset(assetClass:Class<Dynamic>, mipMapping:Bool=true,
                                             optimizeForRenderToTexture:Bool=false,
                                             scale:Float=1, format:Context3DTextureFormat=BGRA,
                                             forcePotTexture:Bool=false):Texture
    {
        var texture:Texture;
        var asset = Type.createEmptyInstance(assetClass);

        if (Std.is(asset, Bitmap))
        {
            texture = Texture.fromBitmap(cast asset, mipMapping,
                                optimizeForRenderToTexture, scale, format, forcePotTexture);
            texture.root.onRestore = function():Void
            {
                texture.root.uploadBitmap(Type.createInstance(assetClass, []));
            };
        }
        else if (Std.is(asset, ByteArrayData))
        {
            texture = Texture.fromAtfData(cast asset, scale, mipMapping, null);
            texture.root.onRestore = function():Void
            {
                texture.root.uploadAtfData(Type.createInstance(assetClass, []));
            };
        }
        else
        {
            throw new ArgumentError("Invalid asset type: " + Type.getClassName(asset));
        }

        asset = null; // avoid that object stays in memory (through 'onRestore' functions)
        return texture;
    }

    /** Creates a texture object from a bitmap.
     *  Beware: you must not dispose the bitmap's data if Starling should handle a lost device
     *  context (except if you handle restoration yourself via "texture.root.onRestore").
     *
     *  @param bitmap   the texture will be created with the bitmap data of this object.
     *  @param generateMipMaps  indicates if mipMaps will be created.
     *  @param optimizeForRenderToTexture  indicates if this texture will be used as
     *                  render target
     *  @param scale    the scale factor of the created texture. This affects the reported
     *                  width and height of the texture object.
     *  @param format   the context3D texture format to use. Pass one of the packed or
     *                  compressed formats to save memory (at the price of reduced image
     *                  quality).
     *  @param forcePotTexture  indicates if the underlying Stage3D texture should be created
     *                  as the power-of-two based "Texture" class instead of the more memory
     *                  efficient "RectangleTexture".
     *  @param async    If you pass a callback function, the texture will be uploaded
     *                  asynchronously, which allows smooth rendering even during the
     *                  loading process. However, don't use the texture before the callback
     *                  has been executed. This is the expected function definition:
     *                  <code>function(texture:Texture, error:ErrorEvent):void;</code>
     *                  The second parameter is optional and typically <code>null</code>.
     */
    public static function fromBitmap(bitmap:Bitmap, generateMipMaps:Bool=true,
                                      optimizeForRenderToTexture:Bool=false,
                                      scale:Float=1, format:Context3DTextureFormat=BGRA,
                                      forcePotTexture:Bool=false,
                                      async:Function=null):Texture
    {
        return fromBitmapData(bitmap.bitmapData, generateMipMaps, optimizeForRenderToTexture,
                              scale, format, forcePotTexture, async);
    }

    /** Creates a texture object from bitmap data.
     *  Beware: you must not dispose 'data' if Starling should handle a lost device context
     *  (except if you handle restoration yourself via "texture.root.onRestore").
     *
     *  @param data     the bitmap data to upload to the texture.
     *  @param generateMipMaps  indicates if mipMaps will be created.
     *  @param optimizeForRenderToTexture  indicates if this texture will be used as
     *                  render target
     *  @param scale    the scale factor of the created texture. This affects the reported
     *                  width and height of the texture object.
     *  @param format   the context3D texture format to use. Pass one of the packed or
     *                  compressed formats to save memory (at the price of reduced image
     *                  quality).
     *  @param forcePotTexture  indicates if the underlying Stage3D texture should be created
     *                  as the power-of-two based "Texture" class instead of the more memory
     *                  efficient "RectangleTexture".
     *  @param async    If you pass a callback function, the texture will be uploaded
     *                  asynchronously, which allows smooth rendering even during the
     *                  loading process. However, don't use the texture before the callback
     *                  has been executed. This is the expected function definition:
     *                  <code>function(texture:Texture, error:ErrorEvent):void;</code>
     *                  The second parameter is optional and typically <code>null</code>.
     */
    public static function fromBitmapData(data:BitmapData, generateMipMaps:Bool=true,
                                          optimizeForRenderToTexture:Bool=false,
                                          scale:Float=1, format:Context3DTextureFormat=BGRA,
                                          forcePotTexture:Bool=false,
                                          async:Function=null):Texture
    {
        var texture:Texture = Texture.empty(data.width / scale, data.height / scale, true,
                                            generateMipMaps, optimizeForRenderToTexture, scale,
                                            format, forcePotTexture);

        texture.root.uploadBitmapData(data, async);
        texture.root.onRestore = function():Void
        {
            texture.root.uploadBitmapData(data);
        };

        return texture;
    }

    /** Creates a texture from ATF data (Adobe Texture Compression).
     *  Beware: you must not dispose 'data' if Starling should handle a lost device context;
     *  alternatively, you can handle restoration yourself via "texture.root.onRestore".
     *
     *  @param data       the raw data from an ATF file.
     *  @param scale      the scale factor of the created texture. This affects the reported
     *                    width and height of the texture object.
     *  @param useMipMaps If the ATF data contains mipmaps, this parameter controls if they
     *                    are used; if it does not, this parameter has no effect.
     *  @param async      If you pass a callback function, the texture will be decoded
     *                    asynchronously, which allows a smooth framerate even during the
     *                    loading process. However, don't use the texture before the callback
     *                    has been executed. This is the expected function definition:
     *                    <code>function(texture:Texture):void;</code>
     *  @param premultipliedAlpha  Indicates if the ATF data contains pixels in PMA format.
     *                    This is "false" for most ATF files, but can be customized in some
     *                    tools.
     */
    public static function fromAtfData(data:ByteArray, scale:Number=1, useMipMaps:Bool=true,
                                       async:Function=null, premultipliedAlpha:Bool=false):Texture
    {
        var context:Context3D = Starling.current.context;
        if (context == null) throw new MissingContextError();

        var atfData:AtfData = new AtfData(data);
        var nativeTexture:flash.display3D.textures.Texture = context.createTexture(
            atfData.width, atfData.height, atfData.format, false);
        var concreteTexture:ConcreteTexture = new ConcretePotTexture(nativeTexture,
            atfData.format, atfData.width, atfData.height, useMipMaps && atfData.numTextures > 1,
            premultipliedAlpha, false, scale);

        concreteTexture.uploadAtfData(data, 0, async);
        concreteTexture.onRestore = function():Void
        {
            concreteTexture.uploadAtfData(data, 0);
        };

        return concreteTexture;
    }

    /** Creates a video texture from a NetStream.
     *
     *  <p>Below, you'll find  a minimal sample showing how to stream a video from a file.
     *  Note that <code>ns.play()</code> is called only after creating the texture, and
     *  outside the <code>onComplete</code>-callback. It's recommended to always make the
     *  calls in this order; otherwise, playback won't start on some platforms.</p>
     *
     *  <listing>
     *  var nc:NetConnection = new NetConnection();
     *  nc.connect(null);
     *  
     *  var ns:NetStream = new NetStream(nc);
     *  var texture:Texture = Texture.fromNetStream(ns, 1, function():void
     *  {
     *      addChild(new Image(texture));
     *  });
     *  
     *  var file:File = File.applicationDirectory.resolvePath("bugs-bunny.m4v");
     *  ns.play(file.url);</listing>
     *
     *  @param stream  the NetStream from which the video data is streamed. Beware that 'play'
     *                 should be called only after the method returns, and outside the
     *                 <code>onComplete</code> callback.
     *  @param scale   the scale factor of the created texture. This affects the reported
     *                 width and height of the texture object.
     *  @param onComplete will be executed when the texture is ready. Contains a parameter
     *                 of type 'Texture'.
     */
    public static function fromNetStream(stream:NetStream, scale:Float=1,
                                         onComplete:Function=null):Texture
    {
        // workaround for bug in NetStream class:
        if (stream.client == stream && !(Reflect.hasField(stream, "onMetaData")))
            stream.client = { onMetaData: function(md:Dynamic):Void {} };

        return fromVideoAttachment("NetStream", stream, scale, onComplete);
    }

    /** Creates a video texture from a camera. Beware that the texture must not be used
     *  before the 'onComplete' callback has been executed; until then, it will have a size
     *  of zero pixels.
     *
     *  <p>Here is a minimal sample showing how to display a camera video:</p>
     *
     *  <listing>
     *  var camera:Camera = Camera.getCamera();
     *  var texture:Texture = Texture.fromCamera(camera, 1, function():void
     *  {
     *      addChild(new Image(texture));
     *  });</listing>
     *
     *  @param camera  the camera from which the video data is streamed.
     *  @param scale   the scale factor of the created texture. This affects the reported
     *                 width and height of the texture object.
     *  @param onComplete will be executed when the texture is ready. May contain a parameter
     *                 of type 'Texture'.
     */
    #if flash
    public static function fromCamera(camera:Camera, scale:Float=1,
                                      onComplete:Function=null):Texture
    {
        return fromVideoAttachment("Camera", camera, scale, onComplete);
    }
    #end

    private static function fromVideoAttachment(type:String, attachment:Dynamic,
                                                scale:Float, onComplete:Function):Texture
    {
        if (!SystemUtil.supportsVideoTexture)
            throw new NotSupportedError("Video Textures are not supported on this platform");

        var context:Context3D = Starling.current.context;
        if (context == null) throw new MissingContextError();

        var base:VideoTexture = context.createVideoTexture();
        var texture:ConcreteTexture = new ConcreteVideoTexture(base, scale);
        texture.attachVideo(type, attachment, onComplete);
        texture.onRestore = function():Void
        {
            texture.root.attachVideo(type, attachment);
        };

        return texture;
    }

    /** Creates a texture with a certain size and color.
     *
     *  @param width   in points; number of pixels depends on scale parameter
     *  @param height  in points; number of pixels depends on scale parameter
     *  @param color   the RGB color the texture will be filled up
     *  @param alpha   the alpha value that will be used for every pixel
     *  @param optimizeForRenderToTexture  indicates if this texture will be used as render target
     *  @param scale   if you omit this parameter, 'Starling.contentScaleFactor' will be used.
     *  @param format  the context3D texture format to use. Pass one of the packed or
     *                 compressed formats to save memory.
     *  @param forcePotTexture  indicates if the underlying Stage3D texture should be created
     *                 as the power-of-two based "Texture" class instead of the more memory
     *                 efficient "RectangleTexture".
     */
    public static function fromColor(width:Float, height:Float,
                                     color:UInt=0xffffff, alpha:Float=1.0,
                                     optimizeForRenderToTexture:Bool=false,
                                     scale:Float=-1, format:String="bgra",
                                     forcePotTexture:Bool=false):Texture
    {
        var texture:Texture = Texture.empty(width, height, true, false,
                                    optimizeForRenderToTexture, scale, format, forcePotTexture);
        texture.root.clear(color, alpha);
        texture.root.onRestore = function():Void
        {
            texture.root.clear(color, alpha);
        };

        return texture;
    }

    /** Creates an empty texture of a certain size.
     *  Beware that the texture can only be used after you either upload some color data
     *  ("texture.root.upload...") or clear the texture ("texture.root.clear()").
     *
     *  @param width   in points; number of pixels depends on scale parameter
     *  @param height  in points; number of pixels depends on scale parameter
     *  @param premultipliedAlpha  the PMA format you will use the texture with. If you will
     *                 use the texture for bitmap data, use "true"; for ATF data, use "false".
     *  @param mipMapping  indicates if mipmaps should be used for this texture. When you upload
     *                 bitmap data, this decides if mipmaps will be created; when you upload ATF
     *                 data, this decides if mipmaps inside the ATF file will be displayed.
     *  @param optimizeForRenderToTexture  indicates if this texture will be used as render target
     *  @param scale   if you omit this parameter, 'Starling.contentScaleFactor' will be used.
     *  @param format  the context3D texture format to use. Pass one of the packed or
     *                 compressed formats to save memory (at the price of reduced image quality).
     *  @param forcePotTexture  indicates if the underlying Stage3D texture should be created
     *                 as the power-of-two based "Texture" class instead of the more memory
     *                 efficient "RectangleTexture".
     */
    public static function empty(width:Float, height:Float, premultipliedAlpha:Bool=true,
                                 mipMapping:Bool=false, optimizeForRenderToTexture:Boolean=false,
                                 scale:Float=-1, format:String="bgra",
                                 forcePotTexture:Bool=false):Texture
    {
        if (scale <= 0) scale = Starling.current.contentScaleFactor;

        var actualWidth:Int, actualHeight:Int;
        var nativeTexture:TextureBase;
        var concreteTexture:ConcreteTexture;
        var context:Context3D = Starling.current.context;

        if (context == null) throw new MissingContextError();

        var origWidth:Float  = width  * scale;
        var origHeight:Float = height * scale;
        var useRectTexture:Bool = !forcePotTexture && !mipMapping &&
            Starling.current.profile != "baselineConstrained" &&
            format.indexOf("compressed") == -1;

        if (useRectTexture)
        {
            actualWidth  = Math.ceil(origWidth  - 0.000000001); // avoid floating point errors
            actualHeight = Math.ceil(origHeight - 0.000000001);

            nativeTexture = context.createRectangleTexture(
                    actualWidth, actualHeight, format, optimizeForRenderToTexture);

            concreteTexture = new ConcreteRectangleTexture(
                    nativeTexture as RectangleTexture, format, actualWidth, actualHeight,
                    premultipliedAlpha, optimizeForRenderToTexture, scale);
        }
        else
        {
            actualWidth  = MathUtil.getNextPowerOfTwo(origWidth);
            actualHeight = MathUtil.getNextPowerOfTwo(origHeight);

            nativeTexture = context.createTexture(
                    actualWidth, actualHeight, format, optimizeForRenderToTexture);

            concreteTexture = new ConcretePotTexture(
                    cast(nativeTexture, flash.display3D.textures.Texture), format,
                    actualWidth, actualHeight, mipMapping, premultipliedAlpha,
                    optimizeForRenderToTexture, scale);
        }

        concreteTexture.onRestore = concreteTexture.clear;

        if (actualWidth - origWidth < 0.001 && actualHeight - origHeight < 0.001)
            return concreteTexture;
        else
            return new SubTexture(concreteTexture, new Rectangle(0, 0, width, height), true);
    }

    /** Creates a texture that contains a region (in pixels) of another texture. The new
     *  texture will reference the base texture; no data is duplicated.
     *
     *  @param texture  The texture you want to create a SubTexture from.
     *  @param region   The region of the parent texture that the SubTexture will show
     *                  (in points).
     *  @param frame    If the texture was trimmed, the frame rectangle can be used to restore
     *                  the trimmed area.
     *  @param rotated  If true, the SubTexture will show the parent region rotated by
     *                  90 degrees (CCW).
     *  @param scaleModifier  The scale factor of the new texture will be calculated by
     *                  multiplying the parent texture's scale factor with this value.
     */
    public static function fromTexture(texture:Texture, region:Rectangle=null,
                                       frame:Rectangle=null, rotated:Bool=false,
                                       scaleModifier:Float=1.0):Texture
    {
        return new SubTexture(texture, region, false, frame, rotated, scaleModifier);
    }

    /** Sets up a VertexData instance with the correct positions for 4 vertices so that
     *  the texture can be mapped onto it unscaled. If the texture has a <code>frame</code>,
     *  the vertices will be offset accordingly.
     *
     *  @param vertexData  the VertexData instance to which the positions will be written.
     *  @param vertexID    the start position within the VertexData instance.
     *  @param attrName    the attribute name referencing the vertex positions.
     *  @param bounds      useful only for textures with a frame. This will position the
     *                     vertices at the correct position within the given bounds,
     *                     distorted appropriately.
     */
    public function adjustVertexData(vertexData:VertexData, vertexID:Int, count:Int):Void
    {
        // override in subclass
    }

    /** Converts texture coordinates into the format required for rendering. While the texture
     * coordinates of an image always use the range <code>[0, 1]</code>, the actual
     * coordinates could be different: you might be working with a SubTexture. This method
     * adjusts the coordinates accordingly.
     *
     * @param texCoords  a vector containing UV coordinates (optionally, among other data).
     *                   U and V coordinates always have to come in pairs. The vector is
     *                   modified in place.
     * @param startIndex the index of the first U coordinate in the vector.
     * @param stride     the distance (in vector elements) of consecutive UV pairs.
     * @param count      the number of UV pairs that should be adjusted, or "-1" for all of them.
     */
    public function adjustTexCoords(texCoords:Vector<Float>,
                                    startIndex:Int=0, stride:Int=0, count:Int=-1):Void
    {
        // override in subclasses
    }

    // properties

    /** The texture frame if it has one (see class description), otherwise <code>null</code>.
     * Only SubTextures can have a frame.
     *
     * <p>CAUTION: not a copy, but the actual object! Do not modify!</p> */
    public var frame(get, never):Rectangle;
    private function get_frame():Rectangle { return null; }

    /** Indicates if the texture should repeat like a wallpaper or stretch the outermost pixels.
     * Note: this only works in textures with sidelengths that are powers of two and
     * that are not loaded from a texture atlas (i.e. no subtextures). @default false */
    public var repeat(get, never):Bool;
    private function get_repeat():Bool { return false; }

    /** The width of the texture in points. */
    public var width(get, never):Float;
    private function get_width():Float { return 0; }

    /** The height of the texture in points. */
    public var height(get, never):Float;
    private function get_height():Float { return 0; }

    /** The width of the texture in pixels (without scale adjustment). */
    public var nativeWidth(get, never):Float;
    private function get_nativeWidth():Float { return 0; }

    /** The height of the texture in pixels (without scale adjustment). */
    public var nativeHeight(get, never):Float;
    private function get_nativeHeight():Float { return 0; }

    /** The scale factor, which influences width and height properties. */
    public var scale(get, never):Float;
    private function get_scale():Float { return 1.0; }

    /** The Stage3D texture object the texture is based on. */
    public var base(get, never):TextureBase;
    private function get_base():TextureBase { return null; }

    /** The concrete texture the texture is based on. */
    public var root(get, never):ConcreteTexture;
    private function get_root():ConcreteTexture { return null; }

    /** The <code>Context3DTextureFormat</code> of the underlying texture data. */
    public var format(get, never):Context3DTextureFormat;
    private function get_format():Context3DTextureFormat { return Context3DTextureFormat.BGRA; }

    /** Indicates if the texture contains mip maps. */
    public var mipMapping(get, never):Bool;
    private function get_mipMapping():Bool { return false; }

    /** Indicates if the alpha values are premultiplied into the RGB values. */
    public var premultipliedAlpha(get, never):Bool;
    private function get_premultipliedAlpha():Bool { return false; }

    /** Returns the maximum size constraint (for both width and height) for textures in the
     * current Context3D profile. */
    public static var maxSize(get, never):Int;
    private static function get_maxSize():Int
    {
        var target:Starling = Starling.current;
        var profile:Context3DProfile = target != null ? target.profile : Context3DProfile.BASELINE;

        if (profile == Context3DProfile.BASELINE || profile == Context3DProfile.BASELINE_CONSTRAINED)
            return 2048;
        else
            return 4096;
    }
}