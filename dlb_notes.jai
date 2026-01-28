/*
Hotfixes:
-----------
Window_Creation/windows.jai:166 (hIcon = icon)

    -   wc.hIcon                = icon;
    +   wc.hIconSm              = icon;

GetRect_LeftHanded/module.jai:585 (is_inside)

    -   return (x >= r.x) && (x <= r.x + r.w) && (y >= r.y) && (y <= r.y + r.h);
    +   return (x >= r.x) && (x < r.x + r.w) && (y >= r.y) && (y < r.y + r.h);

Flat_Pool.jai:89 (use program parameters to allow #import de-duplication)

    -   #module_parameters (DEFAULT_VIRTUAL_MEMORY_RESERVE := 256 * 1024 * 1024, OVERWRITE_ALL_POOLS_ON_RESET := false);
    +   #module_parameters ()(DEFAULT_VIRTUAL_MEMORY_RESERVE := 256 * 1024 * 1024, OVERWRITE_ALL_POOLS_ON_RESET := false);

IProf/instrument.jai:181 (continue the correct loop to make @NoProfile notes work properly)

    -   continue;
    +   continue tc;

Simp/module.jai:38 (SDF glyph support)

    #module_parameters (render_api := Render_API.OPENGL)(SDF_FONTS := false) {

Simp/font.jai:814 (SDF glyph support; top of copy_glyph_to_bitmap)

    #if SDF_FONTS {
        if data.utf32 != #char " " {
            err := FT_Render_Glyph(face.glyph, .SDF);
            if err {
                log_error("Failed to render glyph (utf32 = %) as SDF. err = %\n", data.utf32, err);
            }
        }
    }

    #if SDF_FONTS {
        data.advance += 1;
    }

Simp/immediate.jai:6 (cache texture to prevent useless texture binds)

    @@ -6,6 +6,7 @@ Immediate_State :: struct {
         current_window_info: Window_Info;

         current_shader: *Shader;
    +    current_texture: *Texture;
         texture_render_target: *Texture;
         num_vertices: s32;

    @@ -58,6 +59,7 @@ immediate_set_texture :: (texture: *Texture) {
         }

         backend_set_texture(shader, texture);
    +    state.current_texture = texture;
     }

Simp/shader.jai:33

    set_shader_for_images :: (texture: *Texture) {
        CheckInit();

        target_shader := ifx context.simp.coordinate_system == .LEFT_HANDED then *shader_sprite_left_handed else *shader_sprite_right_handed;
        if state.current_texture != texture || state.current_shader != target_shader {
            immediate_flush();
            if state.current_shader != target_shader {
                immediate_set_shader(target_shader);
                set_projection();
            }
            immediate_set_texture(texture);
        }
    }

Simp/immediate.jai:195

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

IProf/draw.jai:384 (some sort of y-flip fix, check if still needed)

    -   config.draw_text(sx + 24 + name_width + field_width * (j-1) + field_width/2 - config.text_width(report.header[j])/2, sy, report.header[j], color);
    +   config.draw_text(sx + 24 + name_width + field_width * (j-1), sy, report.header[j], color);

Simp/backend/gl.jai:451 (draw_generated_quads; not sure what this patch is referring to.. try without it)

    //  PATCH(dlb): I want this per-texture, but for now, just always use linear sampling.
    //              It seems to break blending though... -_-
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

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

------------------------------
// log windows messages
------------------------------
Input/windows.jai:62 (top of MyWindowProc before the other if/case)

msg_str := "";
if message == {
    case WM_NULL; msg_str = "WM_NULL";
    case WM_CREATE; msg_str = "WM_CREATE";
    case WM_DESTROY; msg_str = "WM_DESTROY";
    case WM_MOVE; msg_str = "WM_MOVE";
    case WM_SIZE; msg_str = "WM_SIZE";
    case WM_SETFOCUS; msg_str = "WM_SETFOCUS";
    case WM_KILLFOCUS; msg_str = "WM_KILLFOCUS";
    case WM_ENABLE; msg_str = "WM_ENABLE";
    case WM_SETREDRAW; msg_str = "WM_SETREDRAW";
    case WM_SETTEXT; msg_str = "WM_SETTEXT";
    case WM_GETTEXT; msg_str = "WM_GETTEXT";
    case WM_GETTEXTLENGTH; msg_str = "WM_GETTEXTLENGTH";
    case WM_PAINT; msg_str = "WM_PAINT";
    case WM_CLOSE; msg_str = "WM_CLOSE";
    case WM_QUERYENDSESSION; msg_str = "WM_QUERYENDSESSION";
    case WM_QUERYOPEN; msg_str = "WM_QUERYOPEN";
    case WM_ENDSESSION; msg_str = "WM_ENDSESSION";
    case WM_QUIT; msg_str = "WM_QUIT";
    case WM_ERASEBKGND; msg_str = "WM_ERASEBKGND";
    case WM_SYSCOLORCHANGE; msg_str = "WM_SYSCOLORCHANGE";
    case WM_SHOWWINDOW; msg_str = "WM_SHOWWINDOW";
    case WM_WININICHANGE; msg_str = "WM_WININICHANGE";
    case WM_DEVMODECHANGE; msg_str = "WM_DEVMODECHANGE";
    case WM_ACTIVATEAPP; msg_str = "WM_ACTIVATEAPP";
    case WM_FONTCHANGE; msg_str = "WM_FONTCHANGE";
    case WM_TIMECHANGE; msg_str = "WM_TIMECHANGE";
    case WM_CANCELMODE; msg_str = "WM_CANCELMODE";
    case WM_SETCURSOR; msg_str = "WM_SETCURSOR";
    case WM_MOUSEACTIVATE; msg_str = "WM_MOUSEACTIVATE";
    case WM_CHILDACTIVATE; msg_str = "WM_CHILDACTIVATE";
    case WM_QUEUESYNC; msg_str = "WM_QUEUESYNC";
    case WM_GETMINMAXINFO; msg_str = "WM_GETMINMAXINFO";
    case WM_NOTIFY; msg_str = "WM_NOTIFY";
    case WM_INPUTLANGCHANGEREQUEST; msg_str = "WM_INPUTLANGCHANGEREQUEST";
    case WM_INPUTLANGCHANGE; msg_str = "WM_INPUTLANGCHANGE";
    case WM_TCARD; msg_str = "WM_TCARD";
    case WM_HELP; msg_str = "WM_HELP";
    case WM_USERCHANGED; msg_str = "WM_USERCHANGED";
    case WM_NOTIFYFORMAT; msg_str = "WM_NOTIFYFORMAT";
    case WM_CONTEXTMENU; msg_str = "WM_CONTEXTMENU";
    case WM_STYLECHANGING; msg_str = "WM_STYLECHANGING";
    case WM_STYLECHANGED; msg_str = "WM_STYLECHANGED";
    case WM_DISPLAYCHANGE; msg_str = "WM_DISPLAYCHANGE";
    case WM_GETICON; msg_str = "WM_GETICON";
    case WM_SETICON; msg_str = "WM_SETICON";
    case WM_NCCREATE; msg_str = "WM_NCCREATE";
    case WM_NCDESTROY; msg_str = "WM_NCDESTROY";
    case WM_NCCALCSIZE; msg_str = "WM_NCCALCSIZE";
    case WM_NCHITTEST; msg_str = "WM_NCHITTEST";
    case WM_NCPAINT; msg_str = "WM_NCPAINT";
    case WM_NCACTIVATE; msg_str = "WM_NCACTIVATE";
    case WM_GETDLGCODE; msg_str = "WM_GETDLGCODE";
    case WM_SYNCPAINT; msg_str = "WM_SYNCPAINT";
    case WM_NCMOUSEMOVE; msg_str = "WM_NCMOUSEMOVE";
    case WM_NCLBUTTONDOWN; msg_str = "WM_NCLBUTTONDOWN";
    case WM_NCLBUTTONUP; msg_str = "WM_NCLBUTTONUP";
    case WM_NCLBUTTONDBLCLK; msg_str = "WM_NCLBUTTONDBLCLK";
    case WM_NCRBUTTONDOWN; msg_str = "WM_NCRBUTTONDOWN";
    case WM_NCRBUTTONUP; msg_str = "WM_NCRBUTTONUP";
    case WM_NCRBUTTONDBLCLK; msg_str = "WM_NCRBUTTONDBLCLK";
    case WM_NCMBUTTONDOWN; msg_str = "WM_NCMBUTTONDOWN";
    case WM_NCMBUTTONUP; msg_str = "WM_NCMBUTTONUP";
    case WM_NCMBUTTONDBLCLK; msg_str = "WM_NCMBUTTONDBLCLK";
    case WM_NCXBUTTONDOWN; msg_str = "WM_NCXBUTTONDOWN";
    case WM_NCXBUTTONUP; msg_str = "WM_NCXBUTTONUP";
    case WM_NCXBUTTONDBLCLK; msg_str = "WM_NCXBUTTONDBLCLK";
    case WM_INPUT_DEVICE_CHANGE; msg_str = "WM_INPUT_DEVICE_CHANGE";
    case WM_INPUT; msg_str = "WM_INPUT";
    case WM_KEYDOWN; msg_str = "WM_KEYDOWN";
    case WM_KEYUP; msg_str = "WM_KEYUP";
    case WM_CHAR; msg_str = "WM_CHAR";
    case WM_DEADCHAR; msg_str = "WM_DEADCHAR";
    case WM_SYSKEYDOWN; msg_str = "WM_SYSKEYDOWN";
    case WM_SYSKEYUP; msg_str = "WM_SYSKEYUP";
    case WM_SYSCHAR; msg_str = "WM_SYSCHAR";
    case WM_SYSDEADCHAR; msg_str = "WM_SYSDEADCHAR";
    case WM_UNICHAR; msg_str = "WM_UNICHAR";
    case UNICODE_NOCHAR; msg_str = "UNICODE_NOCHAR";
    case WM_IME_STARTCOMPOSITION; msg_str = "WM_IME_STARTCOMPOSITION";
    case WM_IME_ENDCOMPOSITION; msg_str = "WM_IME_ENDCOMPOSITION";
    case WM_IME_COMPOSITION; msg_str = "WM_IME_COMPOSITION";
    case WM_INITDIALOG; msg_str = "WM_INITDIALOG";
    case WM_COMMAND; msg_str = "WM_COMMAND";
    case WM_SYSCOMMAND; msg_str = "WM_SYSCOMMAND";
    case WM_TIMER; msg_str = "WM_TIMER";
    case WM_HSCROLL; msg_str = "WM_HSCROLL";
    case WM_VSCROLL; msg_str = "WM_VSCROLL";
    case WM_INITMENU; msg_str = "WM_INITMENU";
    case WM_INITMENUPOPUP; msg_str = "WM_INITMENUPOPUP";
    case WM_GESTURE; msg_str = "WM_GESTURE";
    case WM_GESTURENOTIFY; msg_str = "WM_GESTURENOTIFY";
    case WM_MENUSELECT; msg_str = "WM_MENUSELECT";
    case WM_MENUCHAR; msg_str = "WM_MENUCHAR";
    case WM_ENTERIDLE; msg_str = "WM_ENTERIDLE";
    case WM_MENURBUTTONUP; msg_str = "WM_MENURBUTTONUP";
    case WM_MENUDRAG; msg_str = "WM_MENUDRAG";
    case WM_MENUGETOBJECT; msg_str = "WM_MENUGETOBJECT";
    case WM_UNINITMENUPOPUP; msg_str = "WM_UNINITMENUPOPUP";
    case WM_MENUCOMMAND; msg_str = "WM_MENUCOMMAND";
    case WM_CHANGEUISTATE; msg_str = "WM_CHANGEUISTATE";
    case WM_UPDATEUISTATE; msg_str = "WM_UPDATEUISTATE";
    case WM_QUERYUISTATE; msg_str = "WM_QUERYUISTATE";
    case WM_CTLCOLORMSGBOX; msg_str = "WM_CTLCOLORMSGBOX";
    case WM_CTLCOLOREDIT; msg_str = "WM_CTLCOLOREDIT";
    case WM_CTLCOLORLISTBOX; msg_str = "WM_CTLCOLORLISTBOX";
    case WM_CTLCOLORBTN; msg_str = "WM_CTLCOLORBTN";
    case WM_CTLCOLORDLG; msg_str = "WM_CTLCOLORDLG";
    case WM_CTLCOLORSCROLLBAR; msg_str = "WM_CTLCOLORSCROLLBAR";
    case WM_CTLCOLORSTATIC; msg_str = "WM_CTLCOLORSTATIC";
    case MN_GETHMENU; msg_str = "MN_GETHMENU";
    case WM_MOUSEMOVE; msg_str = "WM_MOUSEMOVE";
    case WM_LBUTTONDOWN; msg_str = "WM_LBUTTONDOWN";
    case WM_LBUTTONUP; msg_str = "WM_LBUTTONUP";
    case WM_LBUTTONDBLCLK; msg_str = "WM_LBUTTONDBLCLK";
    case WM_RBUTTONDOWN; msg_str = "WM_RBUTTONDOWN";
    case WM_RBUTTONUP; msg_str = "WM_RBUTTONUP";
    case WM_RBUTTONDBLCLK; msg_str = "WM_RBUTTONDBLCLK";
    case WM_MBUTTONDOWN; msg_str = "WM_MBUTTONDOWN";
    case WM_MBUTTONUP; msg_str = "WM_MBUTTONUP";
    case WM_MBUTTONDBLCLK; msg_str = "WM_MBUTTONDBLCLK";
    case WM_MOUSEWHEEL; msg_str = "WM_MOUSEWHEEL";
    case WM_XBUTTONDOWN; msg_str = "WM_XBUTTONDOWN";
    case WM_XBUTTONUP; msg_str = "WM_XBUTTONUP";
    case WM_XBUTTONDBLCLK; msg_str = "WM_XBUTTONDBLCLK";
    case WM_MOUSEHWHEEL; msg_str = "WM_MOUSEHWHEEL";
    case WM_SIZING; msg_str = "WM_SIZING";
    case WM_EXITSIZEMOVE; msg_str = "WM_EXITSIZEMOVE";
    case WM_DROPFILES; msg_str = "WM_DROPFILES";
    case WM_DPICHANGED; msg_str = "WM_DPICHANGED";
    case 6; msg_str = "WM_ACTIVATE";
    case 70; msg_str = "WM_WINDOWPOSCHANGING";
    case 71; msg_str = "WM_WINDOWPOSCHANGED";
    case 641; msg_str = "WM_IME_SETCONTEXT";
    case 642; msg_str = "WM_IME_NOTIFY";
    case 648; msg_str = "WM_IME_REQUEST";
    case 674; msg_str = "WM_NCMOUSELEAVE";
    case 533; msg_str = "WM_CAPTURECHANGED";
}
Simpler :: #import "Simpler";
context.logger = Simpler.simpler_logger;
log(ifx msg_str else tprint("(unknown %)", message));

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