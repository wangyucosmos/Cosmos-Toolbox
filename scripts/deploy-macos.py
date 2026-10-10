#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Local Universal Release deployment. Run: /usr/bin/python3 scripts/deploy-macos.py"""
import ctypes
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import uuid

BUNDLE_ID = "com.wangyucosmos.Cosmos-Toolbox"
APP_NAME = "Cosmos Toolbox.app"
REPO = Path(__file__).resolve().parent.parent
PROJECT = REPO / "Apps/CosmosOS/Cosmos Toolbox.xcodeproj"
APPLICATIONS = Path.home() / "Applications"
TARGET = APPLICATIONS / APP_NAME


def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def git(*args):
    return subprocess.check_output(["git", "-C", str(REPO), *args])


def source_revision():
    # Hashes stay local; no source or credential contents are printed.
    head = git("rev-parse", "HEAD").decode("utf-8").strip()
    status = git("status", "--porcelain", "--untracked-files=all")
    fingerprint = hashlib.sha256(git("diff", "--binary", "HEAD") + status).hexdigest()
    return head, bool(status), fingerprint


def identity(path):
    if path.is_symlink() or not path.is_dir():
        raise RuntimeError("App 不是普通目录，拒绝覆盖：" + str(path))
    plist = path / "Contents/Info.plist"
    if plist.is_symlink():
        raise RuntimeError("App 信息文件是符号链接，拒绝覆盖。")
    with plist.open("rb") as handle:
        info = plistlib.load(handle)
    if (info.get("CFBundleIdentifier") != BUNDLE_ID
            or info.get("CFBundleExecutable") != "Cosmos Toolbox"
            or info.get("CFBundlePackageType") != "APPL"):
        raise RuntimeError("App 身份不符，保留原 App 并停止：" + str(path))
    return info


QUIT_AND_CONFIRM = r'''
import AppKit
let destination = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL.path
let mode = CommandLine.arguments[2]
let bundleID = "com.wangyucosmos.Cosmos-Toolbox"
let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleID }
if mode == "quit" {
    for app in apps {
        guard let url = app.bundleURL else { fputs("App 路径未知，未关闭。\n", stderr); exit(1) }
        let path = url.standardizedFileURL.path
        let temporary = path.hasPrefix("/private/tmp/CosmosOS-Daily-") || path.hasPrefix("/tmp/CosmosOS-Daily-")
        guard path == destination || temporary else {
            fputs("同身份 App 来自其他位置，未关闭或替换：\(path)\n", stderr); exit(1)
        }
    }
    for app in apps {
        if !app.terminate() { fputs("App 拒绝正常退出；请处理未保存内容后重试。\n", stderr); exit(1) }
    }
    let limit = Date().addingTimeInterval(30)
    while apps.contains(where: { !$0.isTerminated }) && Date() < limit {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    guard apps.allSatisfy({ $0.isTerminated }) else {
        fputs("App 仍未退出（可能有未保存内容）；部署已停止，不强杀。\n", stderr); exit(1)
    }
    print("旧 App 已正常退出（或原本未运行）。")
} else {
    let limit = Date().addingTimeInterval(10)
    repeat {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleID && $0.bundleURL?.standardizedFileURL.path == destination && !$0.isTerminated
        }) {
            print("已启动：\(destination)；PID \(app.processIdentifier)")
            exit(0)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    } while Date() < limit
    fputs("未确认安装位置的正常 App 进程，未尝试强杀或自动回退。\n", stderr); exit(1)
}
'''


def rename_exclusive(source, destination):
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.renamex_np(os.fsencode(source), os.fsencode(destination), 0x00000004) != 0:  # RENAME_EXCL
        raise OSError(ctypes.get_errno(), "App 原子发布失败，未覆盖目标")


def main():
    if sys.platform != "darwin":
        raise RuntimeError("仅支持本机 macOS 部署。")
    if APPLICATIONS.is_symlink():
        raise RuntimeError("~/Applications 是符号链接，停止部署。")
    APPLICATIONS.mkdir(exist_ok=True)
    lock_path = APPLICATIONS / ".cosmos-deploy.lock"
    fd = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(fd)
        raise RuntimeError("已有部署运行，本次停止。")
    with os.fdopen(fd, "w") as lock:
        if os.path.lexists(TARGET):
            identity(TARGET)
        revision = source_revision()
        work = Path(tempfile.mkdtemp(prefix="CosmosOS-ReleaseDeploy-"))
        log = work / "build.log"
        print("构建日志：", log, flush=True)
        # Xcode may reorder the project file. Restore only byte-order changes
        # whose parsed property-list content is exactly equal.
        project_file = PROJECT / "project.pbxproj"
        original_project = project_file.read_bytes()
        original_copy = work / "project-before.pbxproj"
        original_copy.write_bytes(original_project)
        try:
            with log.open("w", encoding="utf-8") as output:
                run(["xcodebuild", "build", "-project", str(PROJECT), "-scheme", "Cosmos Toolbox",
                     "-configuration", "Release", "-destination", "generic/platform=macOS",
                     "-derivedDataPath", str(work / "DerivedData"), "CODE_SIGNING_ALLOWED=NO",
                     "ONLY_ACTIVE_ARCH=NO", "ARCHS=arm64 x86_64", "PRODUCT_BUNDLE_IDENTIFIER=" + BUNDLE_ID],
                    stdout=output, stderr=subprocess.STDOUT)
        finally:
            if project_file.read_bytes() != original_project:
                def parsed(path):
                    return json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(path)]))
                if parsed(original_copy) == parsed(project_file):
                    project_file.write_bytes(original_project)
        if source_revision() != revision:
            raise RuntimeError("构建期间源码/HEAD 状态变化，未部署；保留构建日志。")
        built = work / "DerivedData/Build/Products/Release" / APP_NAME
        info = identity(built)
        executable = built / "Contents/MacOS" / info["CFBundleExecutable"]
        archs = subprocess.check_output(["lipo", "-archs", str(executable)]).decode("utf-8").split()
        if set(archs) != {"arm64", "x86_64"}:
            raise RuntimeError("构建不是 Universal，未部署。")
        info.update(CosmosBuildCommit=revision[0], CosmosBuildDirty=revision[1],
                    CosmosBuildConfiguration="Release")
        with (built / "Contents/Info.plist").open("wb") as handle:
            plistlib.dump(info, handle)
        run(["codesign", "--force", "--deep", "--sign", "-", str(built)])
        run(["codesign", "--verify", "--deep", "--strict", str(built)])
        helper = work / "lifecycle.swift"
        helper.write_text(QUIT_AND_CONFIRM, encoding="utf-8")
        swift = ["swift", "-module-cache-path", str(work / "ModuleCache"), str(helper), str(TARGET)]
        staged = APPLICATIONS / (".cosmos-install-" + uuid.uuid4().hex + ".app")
        backup = None
        published = False
        try:
            shutil.copytree(built, staged, symlinks=True)
            run(["codesign", "--verify", "--deep", "--strict", str(staged)])
            run(swift + ["quit"])
            if os.path.lexists(TARGET):
                identity(TARGET)
                backups = APPLICATIONS / "Cosmos OS Rollbacks"
                if backups.is_symlink():
                    raise RuntimeError("回退目录是符号链接，停止部署。")
                backups.mkdir(exist_ok=True)
                stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
                backup = backups / ("Cosmos Toolbox-" + stamp + "-" + uuid.uuid4().hex[:8] + ".app")
                TARGET.rename(backup)
            # No overwrite if another program creates a target after the check.
            rename_exclusive(staged, TARGET)
            published = True
        except Exception:
            if backup is not None and not os.path.lexists(TARGET):
                rename_exclusive(backup, TARGET)
            raise
        finally:
            if staged.exists() and not published:
                shutil.rmtree(staged)  # Only this invocation's unique staging directory.
        run(["open", str(TARGET)])
        run(swift + ["confirm"])
        print("版本：", info.get("CFBundleShortVersionString"), "构建：", info.get("CFBundleVersion"))
        print("commit：", revision[0], "（含未提交改动）" if revision[1] else "（已提交源码）")
        print("安装：", TARGET)
        print("回退副本：", backup if backup else "首次安装，无旧版")
        print("部署脚本不读写业务数据；正常启动沿用 App 既有行为，可能写入窗口偏好。")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("部署停止：" + str(error), file=sys.stderr)
        sys.exit(1)
