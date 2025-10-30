@@
@@

+void seq_put_hex_ll(struct seq_file *m, const char *delimiter,
+				unsigned long long v, unsigned int width)
+{
+	unsigned int len;
+	int i;
+	if (delimiter && delimiter[0]) {
+		if (delimiter[1] == 0)
+			seq_putc(m, delimiter[0]);
+		else
+			seq_puts(m, delimiter);
+	}
+	/* If x is 0, the result of __builtin_clzll is undefined */
+	if (v == 0)
+		len = 1;
+	else
+		len = (sizeof(v) * 8 - __builtin_clzll(v) + 3) / 4;
+	if (len < width)
+		len = width;
+	if (m->count + len > m->size) {
+		seq_set_overflow(m);
+		return;
+	}
+	for (i = len - 1; i >= 0; i--) {
+		m->buf[m->count + i] = hex_asc[0xf & v];
+		v = v >> 4;
+	}
+	m->count += len;
+}
+
 void seq_put_decimal_ll(struct seq_file *m, const char *delimiter, long long num)
 {
 	...
 }
