#if OUTLINE > 0
#define OUTLINE_ENABLED
#endif

#if OUTLINE == 1
#define OUTLINE_OUTER
#endif

#if OUTLINE == 2
#define OUTLINE_OUTER
#define OUTLINE_OUTER_COLOR
#endif

#if OUTLINE == 3
#define OUTLINE_OUTER
#define OUTLINE_OUTER_COLOR
#define OUTLINE_INNER
#endif

#if OUTLINE == 4
#define OUTLINE_INNER
#define OUTLINE_INNER_BEVEL
#endif

#if OUTLINE == 5
#define OUTLINE_INNER
#endif