@naysayer101 It's cool that you're experimenting with casting syntax. I tested the options with some real-world code I ported from C:
```c
// Option 1
netcode_write_uint32 :: (p: **u8, value: u32) {
    p.*[0] = cast(u8) (value & 0xFF);
    p.*[1] = cast(u8) ((value >> 8 ) & 0xFF);
    p.*[2] = cast(u8) ((value >> 16) & 0xFF);
    p.*[3] = cast(u8) (value >> 24);
    p.* += 4;
}

// Option 2
netcode_write_uint32 :: (p: **u8, value: u32) {
    p.*[0] = cast(u8, value & 0xFF);
    p.*[1] = cast(u8, (value >> 8 ) & 0xFF);
    p.*[2] = cast(u8, (value >> 16) & 0xFF);
    p.*[3] = cast(u8, value >> 24);
    p.* += 4;
}

// Option 3a (implicit 'cast')
netcode_write_uint32 :: (p: **u8, value: u32) {
    p.*[0] = (value & 0xFF).cast(u8);
    p.*[1] = ((value >> 8 ) & 0xFF).cast(u8);
    p.*[2] = ((value >> 16) & 0xFF).cast(u8);
    p.*[3] = (value >> 24).cast(u8);
    p.* += 4;
}

// Option 3b (explicit 'cast')
netcode_write_uint32 :: (p: **u8, value: u32) {
    p.*[0] = (value & 0xFF).(u8);
    p.*[1] = ((value >> 8 ) & 0xFF).(u8);
    p.*[2] = ((value >> 16) & 0xFF).(u8);
    p.*[3] = (value >> 24).(u8);
    p.* += 4;
}
```
**Option 1**: This is decent, but I dislike having to put extra parenthesis.
**Option 2**: This is the only option that allows a single pair of parenthesis, which improves readability IMO.
**Option 3a**: While this seems good for very small expressions (you use `x` in the example in your email), it's common to cast fairly long expressions, and multiple expressions of different lengths (as in my example above), and I personally find the code most readable when the casts are vertically aligned. Putting the cast at the end of a bunch of long or variable-length expressions hides it.
**Option 3b**: This is even worse than 3a, for all the same reasons, but with the additional factor of no "cast" keyword. It looks nice in the ideal case, but I feel that many casts will become too hidden in practice.

----------
With regard to cast modifiers, like `trunc`, `force`, etc., I think the Option 2 example in the mail, `x = cast(*u8, p + offset, trunc).*;`, is a bad idea because separating the trunc modifier from the cast keyword and type info by a variable-length expression again causes hidden behavior that is difficult to spot in real-world code.

Truncation is unnecessary in this code, but for example:
```c
netcode_write_uint32 :: (p: **u8, value: u32) {
    p.*[0] = cast(u8, value & 0xFF, trunc);
    p.*[1] = cast(u8, (value >> 8 ) & 0xFF, trunc);
    p.*[2] = cast(u8, (value >> 16) & 0xFF, trunc);
    p.*[3] = cast(u8, value >> 24, trunc);
    p.* += 4;
}
```
Personally, I like Option 2 the most, but I would prefer the cast modifier(s) to remain adjacent to the cast keyword:
```c
netcode_write_uint32 :: (p: **u8, value: u32) {
    p.*[0] = cast,trunc(u8, value & 0xFF);
    p.*[1] = cast,trunc(u8, (value >> 8 ) & 0xFF);
    p.*[2] = cast,trunc(u8, (value >> 16) & 0xFF);
    p.*[3] = cast,trunc(u8, value >> 24);
    p.* += 4;
}
```

----------
With regard to cast deferencing, here is a real line of code rewritten with each of the options from your mail:
```c
mac_1 := cast(*MacBuf).* (packet.connect_token_data.data + NETCODE_CONNECT_TOKEN_PRIVATE_BYTES - NETCODE_MAC_BYTES);
mac_2 := cast(*MacBuf, packet.connect_token_data.data + NETCODE_CONNECT_TOKEN_PRIVATE_BYTES - NETCODE_MAC_BYTES).*;
mac_3a := (packet.connect_token_data.data + NETCODE_CONNECT_TOKEN_PRIVATE_BYTES - NETCODE_MAC_BYTES).cast(*MacBuf).*;
mac_3b := (packet.connect_token_data.data + NETCODE_CONNECT_TOKEN_PRIVATE_BYTES - NETCODE_MAC_BYTES).(*MacBuf).*;
```
**Option 1**: Most readable, because all the casting info is together.
**Option 2**: Most syntactically consistent with the rest of the language, but the dereference is annoyingly hidden at the end of the line. I could alleviate this by moving the dereference to later in the code when the variable is used (it gets passed to a procedure, so I would just do `mac_2.*` at that point). This syntax is also the most clear precedence-wise. Precedence confusion is definitely something that happens often with Option 1 unless you make copious use of parethesis.
**Option 3a/b**: Both variants of Option 3 would necessitate splitting the code into two lines, because of how absurdly hidden the cast becomes. This is bad.

----------
If dereferencing in the same line as the cast is important (is it?), here are some new ideas for Option 2's dereferencing syntax, to prevent it hiding at the end of the line:
```c
mac_2a := cast.*(*MacBuf, packet.connect_token_data.data + NETCODE_CONNECT_TOKEN_PRIVATE_BYTES - NETCODE_MAC_BYTES);
mac_2b := cast.*,force(*MacBuf, packet.connect_token_data.data + NETCODE_CONNECT_TOKEN_PRIVATE_BYTES - NETCODE_MAC_BYTES);
mac_2c := cast,force.*(*MacBuf, packet.connect_token_data.data + NETCODE_CONNECT_TOKEN_PRIVATE_BYTES - NETCODE_MAC_BYTES);
```
An even more exploratory idea where the `.*` is simplified to `*` (annoying to parse?):
```c
mac_2d := cast*(*MacBuf, packet.connect_token_data.data + NETCODE_CONNECT_TOKEN_PRIVATE_BYTES - NETCODE_MAC_BYTES);
mac_2e := cast*,force(*MacBuf, packet.connect_token_data.data + NETCODE_CONNECT_TOKEN_PRIVATE_BYTES - NETCODE_MAC_BYTES);
mac_2f := cast,force*(*MacBuf, packet.connect_token_data.data + NETCODE_CONNECT_TOKEN_PRIVATE_BYTES - NETCODE_MAC_BYTES);
```
I don't like 2c and 2f as much, which separate the dereference hint from the cast keyword by an arbitrary length list of cast modifiers. I also think there's something to be said for communicating dereferencing consistently with `.*`, rather than trying to save a character, so I would probably choose 2a/2b over 2d/2e.

Overall, both Option 1 and 2a/2b maintain sane visilibity of important information at the start of the line, and have no obvious downsides. Of those, I prefer 2a/2b, due the improved precedence clarity, which allows me to elide an extra pair of parenthesis in many scenarios.

Curious to hear other people's thoughts.