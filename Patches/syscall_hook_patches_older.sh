#!/bin/bash
# Patches author: backslashxx @ Github
# Shell authon: JackA1ltman <cs2dtzq@163.com>
# Tested kernel versions: 5.4, 4.19, 4.14, 4.9, 4.4, 3.18, 3.10, 3.4
# 20250309

patch_files=(
    arch/arm/kernel/sys_arm.c
    fs/exec.c
    fs/open.c
    fs/read_write.c
    fs/stat.c
    fs/namei.c
    drivers/input/input.c
    security/security.c
    security/selinux/hooks.c
)

PATCH_LEVEL="1.4"
KERNEL_VERSION=$(head -n 3 Makefile | grep -E 'VERSION|PATCHLEVEL' | awk '{print $3}' | paste -sd '.')
FIRST_VERSION=$(echo "$KERNEL_VERSION" | awk -F '.' '{print $1}')
SECOND_VERSION=$(echo "$KERNEL_VERSION" | awk -F '.' '{print $2}')

echo "Current patch version:$PATCH_LEVEL"

for i in "${patch_files[@]}"; do

    if grep -q "ksu" "$i"; then
        echo "Warning: $i contains KernelSU"
        continue
    fi

    case $i in

    # arch/arm/kernel/ changes
    ## sys_arm.c
    arch/arm/kernel/sys_arm.c)
        if [ "$FIRST_VERSION" -lt 4 ] && [ "$SECOND_VERSION" -lt 5 ]; then
            sed -i '/asmlinkage int sys_execve(const char __user \*filenamei,/i \#ifdef CONFIG_KSU\nextern int __attribute__((hot)) ksu_handle_execve_sucompat(int \*fd,\n\t\t\t\tconst char __user \*\*filename_user,\n\t\t\t\tvoid \*__never_use_argv, void \*__never_use_envp,\n\t\t\t\tint \*__never_use_flags);\n#endif' arch/arm/kernel/sys_arm.c
            sed -i '/filename = getname(filenamei);/i \#ifdef CONFIG_KSU\n\tksu_handle_execve_sucompat((int \*)AT_FDCWD, &filenamei, NULL, NULL, NULL);\n#endif' arch/arm/kernel/sys_arm.c
        fi
        ;;

    # fs/ changes
    ## exec.c
    fs/exec.c)
        if [ "$FIRST_VERSION" -lt 4 ] && [ "$SECOND_VERSION" -lt 11 ]; then
            sed -i '/SYSCALL_DEFINE3(execve,/i \#ifdef CONFIG_KSU\nextern __attribute__((hot)) int ksu_handle_execve_sucompat(int \*fd,\n\t\t\t\tconst char __user \*\*filename_user,\n\t\t\t\tvoid \*__never_use_argv,\n\t\t\t\tvoid \*__never_use_envp,\n\t\t\t\tint \*__never_use_flags);\n#endif' fs/exec.c
            sed -i '/struct filename \*path = getname(filename);/i \#ifdef CONFIG_KSU\n\tksu_handle_execve_sucompat((int \*)AT_FDCWD, &filename, NULL, NULL, NULL);\n#endif' fs/exec.c
        else
            sed -i '/^SYSCALL_DEFINE3(execve,/i \#ifdef CONFIG_KSU\nextern bool ksu_execveat_hook __read_mostly;\nextern __attribute__((hot, always_inline)) int ksu_handle_execve_sucompat(int \*fd,\n\t\t\t       const char __user \*\*filename_user,\n\t\t\t       void \*__never_use_argv, void \*__never_use_envp,\n\t\t\t       int \*__never_use_flags);\nextern int ksu_handle_execve_ksud(const char __user \*filename_user,\n\t\t\tconst char __user \*const __user \*__argv);\n#ifdef CONFIG_COMPAT  \/\/ 32-on-64 support\nextern int ksu_handle_compat_execve_ksud(const char __user \*filename_user,\n\t\t\tconst compat_uptr_t __user \*__argv);\n#endif\n#endif' fs/exec.c
            sed -i '/return do_execve(getname(filename), argv, envp);/i \#ifdef CONFIG_KSU\n\tif (unlikely(ksu_execveat_hook))\n\t\tksu_handle_execve_ksud(filename, argv);\n\telse\n\t\tksu_handle_execve_sucompat((int *)AT_FDCWD, &filename, NULL, NULL, NULL);\n#endif' fs/exec.c
            sed -i '/return compat_do_execve(getname(filename), argv, envp);/i \#ifdef CONFIG_KSU \/\/ 32-bit su and 32-on-64 support\n\tif (unlikely(ksu_execveat_hook))\n\t\tksu_handle_compat_execve_ksud(filename, argv);\n\telse\n\t\tksu_handle_execve_sucompat((int *)AT_FDCWD, &filename, NULL, NULL, NULL);\n#endif' fs/exec.c
        fi
        ;;

    ## open.c
    fs/open.c)
        if [ "$FIRST_VERSION" -lt 5 ] && [ "$SECOND_VERSION" -lt 19 ]; then
            sed -i '/SYSCALL_DEFINE3(faccessat, int, dfd, const char __user \*, filename, int, mode)/i \#ifdef CONFIG_KSU\nextern int ksu_handle_faccessat(int \*dfd, const char __user \*\*filename_user, int \*mode,\n\t\t\t                     int \*flags);\n#endif' fs/open.c
            sed -i '/if (mode & ~S_IRWXO)/i \#ifdef CONFIG_KSU\n\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);\n#endif' fs/open.c
        else
            sed -i '/SYSCALL_DEFINE3(faccessat, int, dfd, const char __user \*, filename, int, mode)/i \#ifdef CONFIG_KSU\nextern __attribute__((hot)) int ksu_handle_faccessat(int \*dfd, \n\t\t\t                    const char __user \*\*filename_user, int \*mode, int \*flags);\n#endif' fs/open.c
            sed -i '/return do_faccessat(dfd, filename, mode);/i \#ifdef CONFIG_KSU\n\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);\n#endif' fs/open.c
        fi
        ;;

    ## read_write.c
    fs/read_write.c)
        if [ "$FIRST_VERSION" -lt 5 ] && [ "$SECOND_VERSION" -lt 19 ]; then
            sed -i '/SYSCALL_DEFINE3(read, unsigned int, fd, char __user \*, buf, size_t, count)/i \#ifdef CONFIG_KSU\nextern bool ksu_vfs_read_hook __read_mostly;\nextern int ksu_handle_sys_read(unsigned int fd, char __user \*\*buf_ptr,\n\t\t\tsize_t \*count_ptr);\n#endif' fs/read_write.c
            sed -i '/ret = vfs_read(f.file, buf, count, &pos);/i \#ifdef CONFIG_KSU\n\t\tif (unlikely(ksu_vfs_read_hook)) \n\t\t\tksu_handle_sys_read(fd, &buf, &count);\n#endif'
        else
            sed -i '/SYSCALL_DEFINE3(read, unsigned int, fd, char __user \*, buf, size_t, count)/i\#ifdef CONFIG_KSU\nextern bool ksu_vfs_read_hook __read_mostly;\nextern int ksu_handle_sys_read(unsigned int fd, char __user **buf_ptr,\n\t\t\tsize_t *count_ptr);\n#endif' fs/read_write.c
            sed -i '/return ksys_read(fd, buf, count);/i\#ifdef CONFIG_KSU\n\tif (unlikely(ksu_vfs_read_hook))\n\t\tksu_handle_sys_read(fd, &buf, &count);\n#endif' fs/read_write.c
        fi
        ;;

    ## stat.c
    fs/stat.c)
        sed -i '/#if !defined(__ARCH_WANT_STAT64) || defined(__ARCH_WANT_SYS_NEWFSTATAT)/i \#ifdef CONFIG_KSU\nextern __attribute__((hot)) int ksu_handle_stat(int \*dfd, \n\t\t\t                    const char __user \*\*filename_user, int \*flags);\n#endif' fs/stat.c
        sed -i '0,/\terror = vfs_fstatat(dfd, filename, &stat, flag);/s//#ifdef CONFIG_KSU\n\tksu_handle_stat(\&dfd, \&filename, \&flag);\n#endif\n&/' fs/stat.c
        sed -i ':a;N;$!ba;s/\(\terror = vfs_fstatat(dfd, filename, &stat, flag);\)/#ifdef CONFIG_KSU\n\tksu_handle_stat(\&dfd, \&filename, \&flag);\n#endif\n\1/2' fs/stat.c
        ;;

    ## namei.c
    fs/namei.c)
        if [ "$FIRST_VERSION" -lt 4 ] && [ "$SECOND_VERSION" -lt 5 ]; then
            sed -i '/err = lookup_slow(nd, name, path);/c \ \t\tif (strstr(current->comm, "throne_tracker") == NULL)\n\t\t\terr = lookup_slow(nd, name, path);\n\t\telse\n\t\t\terr = -ENOENT;\n' fs/namei.c
        elif [ "$FIRST_VERSION" -lt 4 ] && [ "$SECOND_VERSION" -lt 19 ]; then
            sed -i '/if (unlikely(err)) {/a \#ifdef CONFIG_KSU\n\t\tif (unlikely(strstr(current->comm, "throne_tracker"))) {\n\t\t\terr = -ENOENT;\n\t\t\tgoto out_err;\n\t\t}\n#endif' fs/namei.c
        fi
        ;;

    # drivers/input changes
    ## input.c
    drivers/input/input.c)
        sed -i '0,/void input_event(struct input_dev \*dev,/s//#ifdef CONFIG_KSU\nextern bool ksu_input_hook __read_mostly;\nextern int ksu_handle_input_handle_event(unsigned int \*type, unsigned int \*code, int \*value);\n#endif\n&/' drivers/input/input.c
        sed -i '0,/\tif (is_event_supported(type, dev->evbit, EV_MAX)) {/s//#ifdef CONFIG_KSU\n\tif (unlikely(ksu_input_hook))\n\t\tksu_handle_input_handle_event(\&type, \&code, \&value);\n#endif\n&/' drivers/input/input.c
        ;;

    # security/ changes
    ## security.c
    security/security.c)
        if [ "$FIRST_VERSION" -lt 4 ] && [ "$SECOND_VERSION" -lt 18 ]; then
            sed -i '/#ifdef CONFIG_BPF_SYSCALL/i \#ifdef CONFIG_KSU\nextern int ksu_handle_prctl(int option, unsigned long arg2, unsigned long arg3,\n\t\t   unsigned long arg4, unsigned long arg5);\nextern int ksu_handle_rename(struct dentry *old_dentry, struct dentry *new_dentry);\nextern int ksu_handle_setuid(struct cred *new, const struct cred *old);\n#endif' security/security.c
            sed -i '/if (unlikely(IS_PRIVATE(old_dentry->d_inode) ||/i \#ifdef CONFIG_KSU\n\tksu_handle_rename(old_dentry, new_dentry);\n#endif' security/security.c
            sed -i '/return security_ops->task_fix_setuid(new, old, flags);/i \#ifdef CONFIG_KSU\n\tksu_handle_setuid(new, old);\n#endif' security/security.c
            sed -i '/return security_ops->task_prctl(option, arg2, arg3, arg4, arg5);/i \#ifdef CONFIG_KSU\n\tksu_handle_prctl(option, arg2, arg3, arg4, arg5);\n#endif' security/security.c
        fi
        ;;

    ## selinux/hooks.c
    security/selinux/hooks.c)
        if [ "$FIRST_VERSION" -lt 4 ] && [ "$SECOND_VERSION" -lt 18 ]; then
            sed -i '/^static int selinux_bprm_set_creds(struct linux_binprm \*bprm)/i static int check_nnp_nosuid(const struct linux_binprm *bprm, struct task_security_struct *old_tsec, struct task_security_struct *new_tsec) {\n    int nnp = (bprm->unsafe & LSM_UNSAFE_NO_NEW_PRIVS);\n    int nosuid = (bprm->file->f_path.mnt->mnt_flags & MNT_NOSUID);\n    int rc;\n\n    if (!nnp && !nosuid)\n        return 0;\n\n    if (new_tsec->sid == old_tsec->sid)\n        return 0;\n\n    rc = security_bounded_transition(old_tsec->sid, new_tsec->sid);\n    if (rc) {\n        if (nnp)\n            return -EPERM;\n        else\n            return -EACCES;\n    }\n    return 0;\n}\n' security/selinux/hooks.c
            sed -i '/if *(bprm->unsafe *& *LSM_UNSAFE_NO_NEW_PRIVS)/, /return *-EPERM;/c\ \t\trc = check_nnp_nosuid(bprm, old_tsec, new_tsec);\n\t\tif (rc)\n\t\t\treturn rc;' security/selinux/hooks.c
            awk '
                                                       BEGIN { insert = 0 }
                                                       /rc = security_transition_sid\(old_tsec->sid, isec->sid,/ { insert = 1 }
                                                       { print }
                                                       /return rc;/ {
                                                         if (insert) {
                                                           print "        rc = check_nnp_nosuid(bprm, old_tsec, new_tsec);"
                                                           print "        if (rc)"
                                                           print "            new_tsec->sid = old_tsec->sid;"
                                                           insert = 0
                                                         }
                                                       }
                                                       ' security/selinux/hooks.c > security/selinux/hooks.c.new && mv security/selinux/hooks.c.new security/selinux/hooks.c
            sed -i '/^\tif ((bprm->file->f_path.mnt->mnt_flags & MNT_NOSUID) ||$/{
                                                       N
                                                       N
                                                       /^\tif ((bprm->file->f_path.mnt->mnt_flags & MNT_NOSUID) ||\n\t    (bprm->unsafe & LSM_UNSAFE_NO_NEW_PRIVS))\n\t\tnew_tsec->sid = old_tsec->sid;$/d
                                                       }' security/selinux/hooks.c
            sed -i '/if (!nnp && !nosuid)/i \#ifdef CONFIG_KSU\n\tstatic u32 ksu_sid;\n\tchar *secdata;\n\tint error;\n\tu32 seclen;\n#endif' security/selinux/hooks.c
            sed -i '/return 0; \/\* No change in credentials \*\//a\\n    if (!ksu_sid)\n        security_secctx_to_secid("u:r:su:s0", strlen("u:r:su:s0"), &ksu_sid);\n\n    error = security_secid_to_secctx(old_tsec->sid, &secdata, &seclen);\n    if (!error) {\n        rc = strcmp("u:r:init:s0", secdata);\n        security_release_secctx(secdata, seclen);\n        if (rc == 0 && new_tsec->sid == ksu_sid)\n            return 0;\n    }' security/selinux/hooks.c
        elif [ "$FIRST_VERSION" -lt 5 ] && [ "$SECOND_VERSION" -lt 10 ]; then
            sed -i '/int nnp = (bprm->unsafe & LSM_UNSAFE_NO_NEW_PRIVS);/i\#ifdef CONFIG_KSU\n    static u32 ksu_sid;\n    char *secdata;\n#endif' security/selinux/hooks.c
            sed -i '/if (!nnp && !nosuid)/i\#ifdef CONFIG_KSU\n    int error;\n    u32 seclen;\n#endif' security/selinux/hooks.c
            sed -i '/return 0; \/\* No change in credentials \*\//a\\n#ifdef CONFIG_KSU\n    if (!ksu_sid)\n        security_secctx_to_secid("u:r:su:s0", strlen("u:r:su:s0"), &ksu_sid);\n\n    error = security_secid_to_secctx(old_tsec->sid, &secdata, &seclen);\n    if (!error) {\n        rc = strcmp("u:r:init:s0", secdata);\n        security_release_secctx(secdata, seclen);\n        if (rc == 0 && new_tsec->sid == ksu_sid)\n            return 0;\n    }\n#endif' security/selinux/hooks.c
        fi
        ;;
    esac

done
