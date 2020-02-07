// XS glue for harfbuzz library.
//
// As conventional this is not documented :) .

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "stdint.h"
#include <string.h>
#include <math.h>
#include <harfbuzz/hb.h>
#include <harfbuzz/hb-ot.h>

typedef const char * bytestring_t;
typedef const char * bytestring_nolen_t;

MODULE = HarfBuzz::Shaper		PACKAGE = HarfBuzz::Shaper		
PROTOTYPES: ENABLE

SV *
hb_version_string()
INIT:
  const char *p;
CODE:
  p = hb_version_string();
  RETVAL = newSVpv(p, strlen(p));
OUTPUT:
    RETVAL

hb_buffer_t *
hb_buffer_create()

void
hb_buffer_clear_contents( hb_buffer_t *buf )

void
hb_buffer_add_utf8(hb_buffer_t *buf, bytestring_t s, size_t length(s), unsigned int offset=0, size_t len=-1)

hb_blob_t *
hb_blob_create_from_file( bytestring_nolen_t s )

void
hb_blob_destroy(hb_blob_t *blob)

hb_face_t *
hb_face_create(hb_blob_t *blob, int index)

hb_font_t *
hb_font_create(hb_face_t *face)

void
hb_ot_font_set_funcs(hb_font_t *font)

void
hb_font_set_scale( hb_font_t *font, int xscale, int yscale)

void
hb_font_set_ptem( hb_font_t *font, float pt )

void
hb_buffer_guess_segment_properties( hb_buffer_t *buf )

int
hb_buffer_get_length( hb_buffer_t *buf )

SV *
hb_feature_from_string( SV *sv )
PREINIT:
  STRLEN len;
  char* s;
  hb_feature_t f;
CODE:
  s = SvPVutf8(sv, len);
  if ( hb_feature_from_string(s, len, &f) )
    RETVAL = newSVpv((char*)&f,sizeof(f));
  else
    XSRETURN_UNDEF;
OUTPUT:
  RETVAL

void
hb_shape( hb_font_t *font, hb_buffer_t *buf )
CODE:
  hb_shape( font, buf, NULL, 0 );

SV *
_hb_shaper( hb_font_t *font, hb_buffer_t *buf, SV* feat )
INIT:
  int n;
  int i;
  AV* results;
  char glyphname[32];
  hb_feature_t* features = NULL;
  results = (AV *)sv_2mortal((SV *)newAV());
CODE:
  /* Do we have features? */
  if ( (SvROK(feat))
       && (SvTYPE(SvRV(feat)) == SVt_PVAV)
       && ((n = av_len((AV *)SvRV(feat))) >= 0)) {

    n++;	/* top index -> length */
    Newx(features, n, hb_feature_t);
    for ( i = 0; i < n; i++ ) {
      hb_feature_t* f;
      f = (hb_feature_t*) SvPV_nolen (*av_fetch ((AV*) SvRV(feat), i, 0));
      features[i] = *f;
    }
    if (0) for ( i = 0; i < n; i++ ) {
      hb_feature_to_string( &features[i], glyphname, 32 );
      fprintf( stderr, "feature[%d] = '%s'\n", i, glyphname );
    }
  }
  else {
    features = NULL;
    n = 0;
  }

  hb_shape( font, buf, features, n );
  if ( features ) Safefree(features);

  n = hb_buffer_get_length(buf);
  hb_glyph_position_t *pos = hb_buffer_get_glyph_positions(buf, NULL);
  hb_glyph_info_t *info = hb_buffer_get_glyph_infos(buf, NULL);
  for ( i = 0; i < n; i++ ) {
    HV * rh;
    hb_codepoint_t gid   = info[i].codepoint;
    rh = (HV *)sv_2mortal((SV *)newHV());
    hv_store(rh, "ax",   2, newSViv(pos[i].x_advance),   0);
    hv_store(rh, "ay",   2, newSViv(pos[i].y_advance),   0);
    hv_store(rh, "dx",   2, newSViv(pos[i].x_offset),    0);
    hv_store(rh, "dy",   2, newSViv(pos[i].y_offset),    0);
    hv_store(rh, "g",    1, newSViv(gid),                0);
    hb_font_get_glyph_name(font, gid,
			   glyphname, sizeof(glyphname));	
    hv_store(rh, "name", 4,
		 newSVpvn(glyphname, strlen(glyphname)),  0);
    av_push(results, newRV_inc((SV *)rh));
  }

  RETVAL = newRV_inc((SV *)results);
OUTPUT:
  RETVAL
