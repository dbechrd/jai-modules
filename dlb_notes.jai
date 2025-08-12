/*
Hotfixes:
-----------
GetRect_LeftHanded/module.jai:585 (is_inside)

    is_inside :: (x: float, y: float, r: Rect) -> bool {
        return (x >= r.x) && (x < r.x + r.w) && (y >= r.y) && (y < r.y + r.h);
    }

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

SDF Fonts:
------------
Simp/font.jai:814 (top of copy_glyph_to_bitmap)

    if data.utf32 != #char " " {
        err := FT_Render_Glyph(face.glyph, .SDF);
        if err {
            log_error("Failed to render glyph (utf32 = %) as SDF. err = %\n", data.utf32, err);
        }
    }

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

------------------------------------
// print notes, print decl notes
------------------------------------
#run {
    #import "Compiler";
    root, exprs := compiler_get_nodes(
        #code proc :: () -> result: int @new_note_here, success: bool @must @check {
            return true;
        }
    );

    print("\n");
    for expr: exprs {
        if expr.kind == .DECLARATION {
            decl := expr.(*Code_Declaration);
            print("decl %", decl.name);
            if decl.notes {
                print(" [");
                for note: decl.notes {
                    print("%", note.text);
                    if it_index < decl.notes.count-1 {
                        print(", ");
                    }
                }
                print("]");
            }
            print("\n");
        }
    }
    print("\n");
}


Notes:
-----------
lambda -> "quick procedure" "=>"
system() -> run_command()

so, in summary, if you want all of the operator overloads, do this:
    using,only(.["=="]) Basic :: #import "Basic";
if you want only specific ones, do this:
    Basic :: #import "Basic";
    operator == :: #procedure_of_call Basic.operator==(Basic.Apollo_Time.{}, Basic.Apollo_Time.{});
    operator == :: #procedure_of_call Basic.operator==(Basic.U128.{}, Basic.U128.{});

*/