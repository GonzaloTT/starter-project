import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/use_cases/publish_article_result.dart';
import '../cubit/publish_article_cubit.dart';
import '../cubit/publish_article_state.dart';
import '../services/article_image_picker.dart';

class PublishArticlePage extends StatelessWidget {
  final ArticleImagePicker imagePicker;

  const PublishArticlePage({Key? key, required this.imagePicker})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('publishArticleBackButton'),
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.chevron_left,
            color: Colors.black,
          ),
        ),
      ),
      body: BlocBuilder<PublishArticleCubit, PublishArticleState>(
        builder: (context, state) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ArticleTextField(
                  fieldKey: const Key('publishArticleTitleField'),
                  hintText: 'Write your title here...',
                  errorText: state.errorFor(PublishArticleField.title),
                  minLines: 2,
                  maxLines: 3,
                  onChanged: context.read<PublishArticleCubit>().titleChanged,
                ),
                const SizedBox(height: 16),
                _ArticleTextField(
                  fieldKey: const Key('publishArticleAuthorField'),
                  hintText: 'Write the author here...',
                  errorText: state.errorFor(PublishArticleField.author),
                  textCapitalization: TextCapitalization.words,
                  onChanged: context.read<PublishArticleCubit>().authorChanged,
                ),
                const SizedBox(height: 16),
                _ArticleTextField(
                  fieldKey: const Key('publishArticleDescriptionField'),
                  hintText: 'Write a short description...',
                  errorText: state.errorFor(
                    PublishArticleField.description,
                  ),
                  minLines: 2,
                  maxLines: 4,
                  onChanged:
                      context.read<PublishArticleCubit>().descriptionChanged,
                ),
                const SizedBox(height: 24),
                _ThumbnailSection(state: state, imagePicker: imagePicker),
                const SizedBox(height: 24),
                _ArticleTextField(
                  fieldKey: const Key('publishArticleContentField'),
                  hintText: 'Add article here...',
                  errorText: state.errorFor(PublishArticleField.content),
                  minLines: 10,
                  maxLines: 18,
                  keyboardType: TextInputType.multiline,
                  onChanged: context.read<PublishArticleCubit>().contentChanged,
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar:
          BlocBuilder<PublishArticleCubit, PublishArticleState>(
        buildWhen: (previous, current) => previous.status != current.status,
        builder: (context, state) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
              child: SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  key: const Key('publishArticleSubmitButton'),
                  onPressed: state.isSubmitting
                      ? null
                      : context.read<PublishArticleCubit>().publish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: Colors.black87,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: state.isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    state.isSubmitting ? 'Publishing...' : 'Publish Article',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThumbnailSection extends StatefulWidget {
  final PublishArticleState state;
  final ArticleImagePicker imagePicker;

  const _ThumbnailSection({required this.state, required this.imagePicker});

  @override
  State<_ThumbnailSection> createState() => _ThumbnailSectionState();
}

class _ThumbnailSectionState extends State<_ThumbnailSection> {
  bool _isPicking = false;

  Future<void> _pickImage() async {
    final cubit = context.read<PublishArticleCubit>();
    setState(() => _isPicking = true);
    try {
      final thumbnail = await widget.imagePicker.pickImage();
      if (!mounted || cubit.isClosed || cubit.state.isSubmitting) return;
      if (thumbnail != null) cubit.thumbnailSelected(thumbnail);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to select an image. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.state.thumbnailError;
    final thumbnail = widget.state.thumbnail;

    return Column(
      children: [
        ElevatedButton.icon(
          key: const Key('publishArticleAttachImageButton'),
          onPressed:
              _isPicking || widget.state.isSubmitting ? null : _pickImage,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Colors.black87,
            elevation: 4,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text(
            'Attach Image',
            style: TextStyle(fontSize: 16),
          ),
        ),
        if (thumbnail != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              Uint8List.fromList(thumbnail.bytes),
              key: const Key('publishArticleImagePreview'),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 180,
                child:
                    Center(child: Text('Preview unavailable for this image.')),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(thumbnail.fileName, textAlign: TextAlign.center),
          TextButton.icon(
            key: const Key('publishArticleRemoveImageButton'),
            onPressed: _isPicking || widget.state.isSubmitting
                ? null
                : context.read<PublishArticleCubit>().thumbnailRemoved,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove image'),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error,
            key: const Key('publishArticleThumbnailError'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _ArticleTextField extends StatelessWidget {
  final Key fieldKey;
  final String hintText;
  final String? errorText;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String> onChanged;

  const _ArticleTextField({
    required this.fieldKey,
    required this.hintText,
    required this.errorText,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFC7C7C7)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
