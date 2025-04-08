/*
Hotfixes:
-----------
Simp/backend/gl.jai:451 (draw_generated_quads)

    //  PATCH(dlb): I want this per-texture, but for now, just always use linear sampling.
    //              It seems to break blending though... -_-
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

Simp/immediate.jai:275

    immediate_line :: (p0: Vector2, p1: Vector2, thickness: float, color: Vector4) {
        CheckSpace(6);

        normal := normalize(Vector2.{ p1.y - p0.y, -(p1.x - p0.x) });
        v0 := .{ p0.x, p0.y } + normal * thickness / 2;
        v1 := .{ p0.x, p0.y } - normal * thickness / 2;
        v2 := .{ p1.x, p1.y } + normal * thickness / 2;
        v3 := .{ p1.x, p1.y } - normal * thickness / 2;

        put_vertex(*v[0], v0, color, 0, 0);
        put_vertex(*v[1], v1, color, 0, 1);
        put_vertex(*v[2], v2, color, 1, 0);

        put_vertex(*v[3], v1, color, 0, 1);
        put_vertex(*v[4], v2, color, 1, 0);
        put_vertex(*v[5], v3, color, 1, 1);
    }

Simp/module.jai:212 (set_scissor)

    h := ifx context.simp.texture_render_target {
        context.simp.texture_render_target.height;
    } else {
        context.simp.current_window_info.window_height;
    }

Input/module.jai:367 (keymap_handle_event)

    if (event.type != .KEYBOARD && event.type != .MOUSE_WHEEL) return false;

    if event.type == .MOUSE_WHEEL {
        assert(event.wheel_delta != 0);
        event.key_pressed = 1;
        event.key_code = xx ifx event.wheel_delta > 0 then Key_Code.MOUSE_WHEEL_UP else Key_Code.MOUSE_WHEEL_DOWN;
    }

SDF Fonts:
------------
Simp/font.jai:814 (top of copy_glyph_to_bitmap)

    if data.utf32 != #char " " {
        err := FT_Render_Glyph(face.glyph, .SDF);
        if err {
            log_error("Failed to render glyph (utf32 = %) as SDF. err = %\n", data.utf32, err);
        }
    }

Simp/backend/gl.jai:183

    shader_text.gl_handle   = get_shader_program(SHADER_TEXT_SDF);

Simp/backend/gl.jai:232

    // TODO: https://cdn.cloudflare.steamstatic.com/apps/valve/2007/SIGGRAPH2007_AlphaTestedMagnification.pdf
    // TODO: https://www.youtube.com/watch?v=1b5hIMqz_wM&t=275s
    SHADER_TEXT_SDF :: #string END
    OUT_IN vec2 TextureCoords;
    OUT_IN vec4 iterated_color;

    #ifdef VERTEX_SHADER
    in vec4 vert_position;
    in vec4 vert_color;
    in vec2 vert_uv0;

    uniform mat4 projection;

    void main() {
        gl_Position     = projection * vec4(vert_position.xy, 0.0, 1.0);
        iterated_color  = vert_color;
        TextureCoords   = vert_uv0;
    }
    #endif // VERTEX_SHADER

    #ifdef FRAGMENT_SHADER
    out vec4 color;

    uniform sampler2D text_sampler;
    uniform vec4 text_color;

    void main () {
        float inner_smooth = 0.47;  // where the smoothing between glyph color and outline begins
        float inner_radius = 0.55;  // where the outline starts
        float outer_radius = 0.60;  // where the outline ends

        vec4 col = iterated_color;
        float texel = texture(text_sampler, TextureCoords).a;
        float signed_dist = 1.0 - texel;
        if (signed_dist >= outer_radius) {
            discard;
        }
        if (signed_dist >= inner_radius) {
            // TODO: outline color
            col.xyz = vec3(0);

            // Smooth the outline outer border [inner_radius, outer_radius] -> [1, 0]
            col.a = 1.0 - ((signed_dist - inner_radius) / (outer_radius - inner_radius));
        } else if (signed_dist >= inner_smooth) {
            // [inner_smooth, inner_radius] -> [0, 1]
            float alpha = (signed_dist - inner_smooth) / (inner_radius - inner_smooth);

            // Smooth the colored glyph's outer border against the outline
            col.xyz = mix(col.xyz, vec3(0), alpha);

            // Debug: Show smoothing as red/green gradient
            // col.xyz = mix(vec3(1,0,0), vec3(0,1,0), alpha);
        }
        color = col;
        // color = vec4(vec3(signed_dist), 1);
    }
    #endif // FRAGMENT_SHADER
    END

-----------------------------------
// git put version into code
-----------------------------------
VERSION :: #run -> string {
    result, revision := run_command("git", "rev-parse", "--short", "HEAD", capture_and_return_output = true);
    if revision return sprint("0.3.7-%", trim(revision));
    return "0.3.7-dev";
}

-----------------------------------
// enumerate displays/monitors
-----------------------------------
my_context: #Context;
main :: () {
    my_context = context;
    #if OS == .WINDOWS {
        #import "Windows";
        #import "Remap_Context";
        enum_proc :: (hMonitor: HMONITOR, hdcMonitor: HDC, lprcMonitor: *RECT, dwData: LPARAM) -> BOOL #c_call {
            push_context my_context {
                log("monitor % rect %,%,%,%.\n", hMonitor, lprcMonitor.left, lprcMonitor.top, lprcMonitor.right, lprcMonitor.bottom);
            }
            return .TRUE;
        }
        result := EnumDisplayMonitors(null, null, enum_proc, 0);
        print("result = %\n", result);
    }
}

Notes:
-----------
lambda -> "quick procedure" "=>"
system() -> run_command()

using,only(Vector2) Math :: #import "Math";
operator+ :: #procedure_of_call Math.operator+(Vector2.{}, Vector2.{});

*/